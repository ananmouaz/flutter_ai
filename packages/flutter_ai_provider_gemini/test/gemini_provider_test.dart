import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_ai_provider_gemini/flutter_ai_provider_gemini.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

http.Client _sseClient(List<String> lines, {int statusCode = 200}) {
  return MockClient.streaming((request, bodyStream) async {
    final body = lines.map((l) => '$l\n').join();
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      statusCode,
    );
  });
}

List<String> _dataLines(List<Map<String, Object?>> data) =>
    [for (final d in data) 'data: ${jsonEncode(d)}'];

void main() {
  group('GeminiEventParser', () {
    test('emits start, text deltas, and finish', () {
      final parser = GeminiEventParser(messageId: 'a1');
      final events = [
        ...parser.parse({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'Hello'},
                ],
              },
            },
          ],
        }),
        ...parser.parse({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': ' world'},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
          'usageMetadata': {
            'promptTokenCount': 8,
            'candidatesTokenCount': 5,
            'totalTokenCount': 13,
            'cachedContentTokenCount': 2,
            'thoughtsTokenCount': 3,
          },
        }),
      ];

      expect(events.first, isA<MessageStarted>());
      expect(events.whereType<TextDelta>().map((e) => e.delta), [
        'Hello',
        ' world',
      ]);
      final finished = events.last as MessageFinished;
      expect(finished.reason, FinishReason.stop);
      expect(finished.usage?.inputTokens, 8);
      expect(finished.usage?.outputTokens, 5);
      expect(finished.usage?.totalTokens, 13);
      expect(finished.usage?.cachedInputTokens, 2);
      expect(finished.usage?.reasoningTokens, 3);
    });

    test('maps thought parts to ReasoningDelta', () {
      final parser = GeminiEventParser();
      final events = parser.parse({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'thinking…', 'thought': true},
              ],
            },
          },
        ],
      });
      expect(events.whereType<ReasoningDelta>().single.delta, 'thinking…');
    });

    test('surfaces a mid-stream error payload and suppresses finalize', () {
      final parser = GeminiEventParser(messageId: 'a1');
      final events = parser.parse({
        'error': {'code': 429, 'message': 'Resource exhausted'},
      });
      final err = events.whereType<StreamErrorEvent>().single;
      expect(err.error, 'Resource exhausted');
      expect(err.messageId, 'a1');
      // No synthetic MessageFinished(stop) after the error.
      expect(parser.finalize(), isEmpty);
    });

    test('a blocked prompt finishes as content-filtered, not empty success',
        () {
      final parser = GeminiEventParser(messageId: 'a1');
      final events = parser.parse({
        'promptFeedback': {'blockReason': 'SAFETY'},
      });
      final finished = events.whereType<MessageFinished>().single;
      expect(finished.reason, FinishReason.contentFilter);
      expect(parser.finalize(), isEmpty);
    });

    test(
        'expands a functionCall into start/delta/ready and finishes as toolCalls',
        () {
      final parser = GeminiEventParser(messageId: 'a1');
      final events = parser.parse({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'functionCall': {
                    'name': 'get_weather',
                    'args': {'city': 'London'},
                  },
                },
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      });

      final started = events.whereType<ToolCallStarted>().single;
      expect(started.toolName, 'get_weather');
      expect(
        jsonDecode(events.whereType<ToolCallDelta>().single.argumentsDelta),
        {'city': 'London'},
      );
      final ready = events.whereType<ToolCallReady>().single;
      expect(ready.toolCallId, started.toolCallId);
      expect(
        events.whereType<MessageFinished>().single.reason,
        FinishReason.toolCalls,
      );
    });

    test('gives duplicate-named functionCalls in one chunk distinct ids', () {
      final parser = GeminiEventParser(messageId: 'a1');
      final events = parser.parse({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'functionCall': {
                    'name': 'search',
                    'args': {'q': 'cats'},
                  },
                },
                {
                  'functionCall': {
                    'name': 'search',
                    'args': {'q': 'dogs'},
                  },
                },
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      });

      final started = events.whereType<ToolCallStarted>().toList();
      expect(started, hasLength(2));
      expect(started[0].toolName, 'search');
      expect(started[1].toolName, 'search');
      // Same name, but distinct ids so their results never collide.
      expect(started[0].toolCallId, isNot(started[1].toolCallId));
    });

    test('surfaces grounding chunks as SourcePart citations', () {
      final parser = GeminiEventParser();
      final events = parser.parse({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Lisbon is sunny.'},
              ],
            },
            'groundingMetadata': {
              'groundingChunks': [
                {
                  'web': {'uri': 'https://x.test/lisbon', 'title': 'Lisbon'},
                },
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      });

      final source = events
          .whereType<PartReceived>()
          .map((e) => e.part)
          .whereType<SourcePart>()
          .single;
      expect(source.url.toString(), 'https://x.test/lisbon');
      expect(source.title, 'Lisbon');
    });
  });

  group('GeminiProvider.send', () {
    test('streams events end-to-end over a mock client', () async {
      Map<String, Object?> textChunk(String text, {String? finish}) => {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': text},
                  ],
                },
                if (finish != null) 'finishReason': finish,
              },
            ],
          };
      final lines = _dataLines([
        textChunk('Hi'),
        textChunk('!', finish: 'STOP'),
      ]);
      final provider =
          GeminiProvider(apiKey: 'test', client: _sseClient(lines));

      final events = await provider
          .send(const AiConversation(id: 'c', messages: []))
          .toList();

      final processor = MessageProcessor();
      for (final event in events) {
        processor.apply(event);
      }
      expect(processor.conversation.messages.single.text, 'Hi!');
      expect(
        processor.conversation.messages.single.status,
        AiMessageStatus.complete,
      );
    });

    test('builds the request: header, system instruction, grounding tool',
        () async {
      late http.Request captured;
      final provider = GeminiProvider(
        apiKey: 'k',
        enableGrounding: true,
        client: MockClient.streaming((request, bodyStream) async {
          captured = request as http.Request;
          const body =
              'data: {"candidates":[{"content":{},"finishReason":"STOP"}]}\n';
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(body)),
            200,
          );
        }),
      );

      await provider
          .send(
            const AiConversation(
              id: 'c',
              messages: [
                AiMessage(
                  id: 's',
                  role: AiRole.system,
                  parts: [TextPart('Be terse.')],
                ),
                AiMessage(id: 'u', role: AiRole.user, parts: [TextPart('Hi')]),
              ],
            ),
          )
          .toList();

      expect(captured.headers['x-goog-api-key'], 'k');
      expect(captured.url.toString(), contains(':streamGenerateContent'));
      final body = (jsonDecode(captured.body) as Map).cast<String, Object?>();
      expect(
        ((body['systemInstruction'] as Map)['parts'] as List).first,
        {'text': 'Be terse.'},
      );
      final tools = body['tools']! as List;
      expect(tools.any((t) => (t as Map).containsKey('googleSearch')), isTrue);
    });

    test('maps responseFormat to generationConfig.responseSchema', () async {
      late http.Request captured;
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient.streaming((request, bodyStream) async {
          captured = request as http.Request;
          const body =
              'data: {"candidates":[{"content":{},"finishReason":"STOP"}]}\n';
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(body)),
            200,
          );
        }),
      );

      await provider
          .send(
            const AiConversation(
              id: 'c',
              messages: [
                AiMessage(id: 'u', role: AiRole.user, parts: [TextPart('Hi')]),
              ],
            ),
            options: const AiRequestOptions(
              responseFormat: AiResponseFormat(
                schema: {
                  'type': 'object',
                  'properties': {
                    'x': {'type': 'number'},
                  },
                },
              ),
            ),
          )
          .toList();

      final body = (jsonDecode(captured.body) as Map).cast<String, Object?>();
      final config = (body['generationConfig'] as Map).cast<String, Object?>();
      expect(config['responseMimeType'], 'application/json');
      expect((config['responseSchema'] as Map)['type'], 'object');
    });

    test('emits a StreamErrorEvent on a non-200 response', () async {
      final provider = GeminiProvider(
        apiKey: 'bad',
        client: _sseClient(['nope'], statusCode: 403),
      );
      final events = await provider
          .send(const AiConversation(id: 'c', messages: []))
          .toList();
      expect(events.single, isA<StreamErrorEvent>());
    });

    test('emits a StreamErrorEvent when the transport throws', () async {
      final provider = GeminiProvider(
        apiKey: 'test',
        client: MockClient.streaming((request, bodyStream) async {
          throw const SocketException('connection refused');
        }),
      );
      final events = await provider
          .send(const AiConversation(id: 'c', messages: []))
          .toList();
      expect(events.single, isA<StreamErrorEvent>());
    });

    test('retries a transient 503 then succeeds', () async {
      var calls = 0;
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient.streaming((request, _) async {
          calls++;
          if (calls == 1) {
            return http.StreamedResponse(
              Stream<List<int>>.value(utf8.encode('busy')),
              503,
            );
          }
          const body =
              'data: {"candidates":[{"content":{},"finishReason":"STOP"}]}\n';
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(body)),
            200,
          );
        }),
      );
      final events = await provider
          .send(const AiConversation(id: 'c', messages: []))
          .toList();
      expect(calls, 2);
      expect(events.whereType<StreamErrorEvent>(), isEmpty);
    });

    test('emits a StreamErrorEvent on a wrong-shape chunk without throwing',
        () async {
      // Valid JSON, wrong shape: `candidates: [null]` makes the parser's cast
      // throw; the stream must continue past the bad chunk, not die.
      final provider = GeminiProvider(
        apiKey: 'k',
        client: _sseClient(_dataLines([
          {
            'candidates': [null],
          },
          {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          },
        ])),
      );
      final events = await provider
          .send(const AiConversation(id: 'c', messages: []))
          .toList();
      expect(events.whereType<StreamErrorEvent>(), isNotEmpty);
      expect(events.whereType<TextDelta>().map((e) => e.delta), contains('ok'));
    });

    test('surfaces a message-scoped StreamErrorEvent (no finalize) on a stall',
        () async {
      final controller = StreamController<List<int>>();
      controller.add(utf8.encode(
        'data: {"candidates":[{"content":{"parts":[{"text":"hi"}]}}]}\n',
      ));
      final provider = GeminiProvider(
        apiKey: 'k',
        timeout: const Duration(milliseconds: 50),
        client: MockClient.streaming((request, _) async {
          return http.StreamedResponse(controller.stream, 200);
        }),
      );
      final events = await provider
          .send(const AiConversation(id: 'c', messages: []))
          .toList();
      await controller.close();
      final errors = events.whereType<StreamErrorEvent>().toList();
      expect(errors, isNotEmpty);
      expect(errors.last.messageId, isNotNull); // marks the in-flight message
      expect(events.whereType<MessageFinished>(), isEmpty);
    });

    test('omits googleSearch when function tools are present with grounding',
        () async {
      late http.Request captured;
      final provider = GeminiProvider(
        apiKey: 'k',
        enableGrounding: true,
        client: MockClient.streaming((request, _) async {
          captured = request as http.Request;
          const body =
              'data: {"candidates":[{"content":{},"finishReason":"STOP"}]}\n';
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(body)),
            200,
          );
        }),
      );
      await provider.send(
        const AiConversation(id: 'c', messages: []),
        tools: [
          const ToolDefinition(
            name: 'get_weather',
            description: 'Look up weather',
            parametersSchema: {'type': 'object'},
          ),
        ],
      ).toList();
      final body = (jsonDecode(captured.body) as Map).cast<String, Object?>();
      final tools = (body['tools']! as List).cast<Map<String, Object?>>();
      // Function declarations win; googleSearch is dropped to avoid a 400.
      expect(tools.any((t) => t.containsKey('functionDeclarations')), isTrue);
      expect(tools.any((t) => t.containsKey('googleSearch')), isFalse);
    });
  });

  test('encodes image attachments as inlineData', () async {
    late http.Request captured;
    const stop =
        'data: {"candidates":[{"content":{},"finishReason":"STOP"}]}\n';
    final provider = GeminiProvider(
      apiKey: 'k',
      client: MockClient.streaming((request, _) async {
        captured = request as http.Request;
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode(stop)),
          200,
        );
      }),
    );
    await provider
        .send(
          AiConversation(
            id: 'c',
            messages: [
              AiMessage(
                id: 'u',
                role: AiRole.user,
                parts: [
                  const TextPart('what is this?'),
                  FilePart(
                      mediaType: 'image/png',
                      bytes: Uint8List.fromList([1, 2, 3])),
                ],
              ),
            ],
          ),
        )
        .toList();
    final body = (jsonDecode(captured.body) as Map).cast<String, Object?>();
    final parts = ((body['contents']! as List).first as Map)['parts'] as List;
    final inline =
        parts.firstWhere((p) => (p as Map).containsKey('inlineData')) as Map;
    expect((inline['inlineData'] as Map)['data'], 'AQID');
  });

  group('GeminiProvider multi-turn & finalize', () {
    test('mints a unique message id per turn (no cross-turn folding)',
        () async {
      const body = 'data: {"candidates":[{"content":{"parts":[{"text":"hi"}]},'
          '"finishReason":"STOP"}]}\n';
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient.streaming((request, _) async {
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(body)),
            200,
          );
        }),
      );
      final processor = MessageProcessor();
      for (final e
          in await provider.send(const AiConversation(id: 'c')).toList()) {
        processor.apply(e);
      }
      for (final e
          in await provider.send(const AiConversation(id: 'c')).toList()) {
        processor.apply(e);
      }
      // Two turns → two distinct assistant messages, not one merged bubble.
      expect(processor.conversation.messages.length, 2);
    });

    test('emits functionResponses in call order for duplicate-named tool calls',
        () async {
      late http.Request captured;
      const stop =
          'data: {"candidates":[{"content":{},"finishReason":"STOP"}]}\n';
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient.streaming((request, _) async {
          captured = request as http.Request;
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(stop)),
            200,
          );
        }),
      );

      // One assistant turn with TWO calls to the same tool, then a tool turn
      // whose results are in the OPPOSITE order. The wire functionResponses
      // must still be ordered to match the calls (Gemini matches by position).
      await provider
          .send(
            const AiConversation(
              id: 'c',
              messages: [
                AiMessage(
                  id: 'u',
                  role: AiRole.user,
                  parts: [TextPart('search cats and dogs')],
                ),
                AiMessage(
                  id: 'a',
                  role: AiRole.assistant,
                  parts: [
                    ToolCallPart(
                      toolCallId: 'call-0',
                      toolName: 'search',
                      args: {'q': 'cats'},
                    ),
                    ToolCallPart(
                      toolCallId: 'call-1',
                      toolName: 'search',
                      args: {'q': 'dogs'},
                    ),
                  ],
                ),
                AiMessage(
                  id: 't',
                  role: AiRole.tool,
                  parts: [
                    // Deliberately reversed relative to the calls.
                    ToolResultPart(
                      toolCallId: 'call-1',
                      result: {'hits': 'dogs-result'},
                    ),
                    ToolResultPart(
                      toolCallId: 'call-0',
                      result: {'hits': 'cats-result'},
                    ),
                  ],
                ),
              ],
            ),
          )
          .toList();

      final body = (jsonDecode(captured.body) as Map).cast<String, Object?>();
      final contents = (body['contents']! as List).cast<Map<String, Object?>>();
      final toolTurn = contents.last;
      final responseParts = (toolTurn['parts']! as List)
          .cast<Map<String, Object?>>()
          .map((p) => (p['functionResponse']! as Map).cast<String, Object?>())
          .toList();

      // Two responses, in CALL order, each carrying its own call's payload.
      expect(responseParts, hasLength(2));
      expect(responseParts[0]['name'], 'search');
      expect(responseParts[1]['name'], 'search');
      expect(
        (responseParts[0]['response'] as Map)['hits'],
        'cats-result', // call-0 first
      );
      expect(
        (responseParts[1]['response'] as Map)['hits'],
        'dogs-result', // call-1 second
      );
    });

    test('coalesces tool results split across consecutive tool messages',
        () async {
      late http.Request captured;
      const stop =
          'data: {"candidates":[{"content":{},"finishReason":"STOP"}]}\n';
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient.streaming((request, _) async {
          captured = request as http.Request;
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(stop)),
            200,
          );
        }),
      );

      // Two calls answered by TWO separate tool messages (one result each).
      // Neither result may be dropped.
      await provider
          .send(
            const AiConversation(
              id: 'c',
              messages: [
                AiMessage(
                  id: 'u',
                  role: AiRole.user,
                  parts: [TextPart('search cats and dogs')],
                ),
                AiMessage(
                  id: 'a',
                  role: AiRole.assistant,
                  parts: [
                    ToolCallPart(
                      toolCallId: 'call-0',
                      toolName: 'search',
                      args: {'q': 'cats'},
                    ),
                    ToolCallPart(
                      toolCallId: 'call-1',
                      toolName: 'search',
                      args: {'q': 'dogs'},
                    ),
                  ],
                ),
                AiMessage(id: 't0', role: AiRole.tool, parts: [
                  ToolResultPart(
                    toolCallId: 'call-0',
                    result: {'hits': 'cats-result'},
                  ),
                ]),
                AiMessage(id: 't1', role: AiRole.tool, parts: [
                  ToolResultPart(
                    toolCallId: 'call-1',
                    result: {'hits': 'dogs-result'},
                  ),
                ]),
              ],
            ),
          )
          .toList();

      final body = (jsonDecode(captured.body) as Map).cast<String, Object?>();
      final contents = (body['contents']! as List).cast<Map<String, Object?>>();
      final toolTurn = contents.last;
      final responseParts = (toolTurn['parts']! as List)
          .cast<Map<String, Object?>>()
          .map((p) => (p['functionResponse']! as Map).cast<String, Object?>())
          .toList();

      // A single coalesced tool turn carrying BOTH results in call order.
      expect(responseParts, hasLength(2));
      expect((responseParts[0]['response'] as Map)['hits'], 'cats-result');
      expect((responseParts[1]['response'] as Map)['hits'], 'dogs-result');
    });

    test('finalizes a stream that ends without a finishReason', () async {
      const body =
          'data: {"candidates":[{"content":{"parts":[{"text":"hi"}]}}]}\n';
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient.streaming((request, _) async {
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode(body)),
            200,
          );
        }),
      );
      final processor = MessageProcessor();
      for (final e
          in await provider.send(const AiConversation(id: 'c')).toList()) {
        processor.apply(e);
      }
      expect(
        processor.conversation.messages.single.status,
        AiMessageStatus.complete,
      );
    });
  });

  group('embed', () {
    test('POSTs batchEmbedContents and maps values with indices', () async {
      late http.Request captured;
      late Map<String, Object?> payload;
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient((request) async {
          captured = request;
          payload = (jsonDecode(request.body) as Map).cast<String, Object?>();
          return http.Response(
            jsonEncode({
              'embeddings': [
                {
                  'values': [0.1, 0.2, 0.3],
                },
                {
                  'values': [0.4, 0.5],
                },
              ],
            }),
            200,
          );
        }),
      );

      final embeddings = await provider.embed(['hello', 'world']);

      expect(captured.headers['x-goog-api-key'], 'k');
      expect(
        captured.url.toString(),
        endsWith('/models/text-embedding-004:batchEmbedContents'),
      );
      final requests = payload['requests']! as List;
      expect(requests.length, 2);
      expect(
        ((requests.first as Map)['content'] as Map)['parts'],
        [
          {'text': 'hello'},
        ],
      );
      expect(embeddings, [
        const AiEmbedding([0.1, 0.2, 0.3], index: 0),
        const AiEmbedding([0.4, 0.5], index: 1),
      ]);
    });

    test('honors an explicit embedding model', () async {
      late http.Request captured;
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'embeddings': const <Object?>[]}),
            200,
          );
        }),
      );

      await provider.embed(['x'], model: 'gemini-embedding-001');

      expect(
        captured.url.toString(),
        endsWith('/models/gemini-embedding-001:batchEmbedContents'),
      );
    });

    test('is discoverable as an EmbeddingProvider at runtime', () {
      final LlmProvider provider = GeminiProvider(apiKey: 'k');
      expect(provider is EmbeddingProvider, isTrue);
    });
  });

  group('countTokens', () {
    test('POSTs countTokens with mapped contents and returns totalTokens',
        () async {
      late http.Request captured;
      late Map<String, Object?> payload;
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient((request) async {
          captured = request;
          payload = (jsonDecode(request.body) as Map).cast<String, Object?>();
          return http.Response(jsonEncode({'totalTokens': 42}), 200);
        }),
      );

      final tokens = await provider.countTokens(
        const AiConversation(
          id: 'c',
          messages: [
            AiMessage(id: 'u', role: AiRole.user, parts: [TextPart('Hi')]),
          ],
        ),
        options: const AiRequestOptions(model: 'gemini-2.5-flash'),
      );

      expect(tokens, 42);
      expect(
        captured.url.toString(),
        endsWith('/models/gemini-2.5-flash:countTokens'),
      );
      final contents = payload['contents']! as List;
      expect((contents.single as Map)['role'], 'user');
      expect(
        (contents.single as Map)['parts'],
        [
          {'text': 'Hi'},
        ],
      );
    });

    test('throws a typed LlmException on a non-200', () async {
      final provider = GeminiProvider(
        apiKey: 'k',
        client: MockClient((request) async => http.Response('boom', 500)),
      );

      await expectLater(
        provider.countTokens(const AiConversation(id: 'c')),
        throwsA(isA<LlmServerException>()),
      );
    });

    test('is discoverable as a TokenCounter at runtime', () {
      final LlmProvider provider = GeminiProvider(apiKey: 'k');
      expect(provider is TokenCounter, isTrue);
    });
  });
}

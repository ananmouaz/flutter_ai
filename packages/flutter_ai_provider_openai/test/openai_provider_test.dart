import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_ai_provider_openai/flutter_ai_provider_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Builds a streaming mock client that emits [lines] as an SSE body.
http.Client _sseClient(List<String> lines, {int statusCode = 200}) {
  return MockClient.streaming((request, bodyStream) async {
    final body = lines.map((l) => '$l\n').join();
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      statusCode,
    );
  });
}

void main() {
  group('OpenAiChunkParser', () {
    test('emits start, text deltas, and finish', () {
      final parser = OpenAiChunkParser();
      final events = [
        ...parser.parse({
          'id': 'chatcmpl-1',
          'choices': [
            {
              'delta': {'content': 'Hello'},
            },
          ],
        }),
        ...parser.parse({
          'id': 'chatcmpl-1',
          'choices': [
            {
              'delta': {'content': ' world'},
              'finish_reason': 'stop',
            },
          ],
        }),
        // Trailing usage chunk (stream_options.include_usage), empty choices.
        ...parser.parse({
          'id': 'chatcmpl-1',
          'choices': const [],
          'usage': {
            'prompt_tokens': 9,
            'completion_tokens': 12,
            'total_tokens': 21,
            'prompt_tokens_details': {'cached_tokens': 4},
          },
        }),
        ...parser.finalize(),
      ];

      expect(events[0], isA<MessageStarted>());
      expect(events.whereType<TextDelta>().map((e) => e.delta), [
        'Hello',
        ' world',
      ]);
      // Finish is deferred to finalize() so it can carry usage.
      final finished = events.whereType<MessageFinished>().single;
      expect(finished.reason, FinishReason.stop);
      expect(finished.usage?.inputTokens, 9);
      expect(finished.usage?.outputTokens, 12);
      expect(finished.usage?.totalTokens, 21);
      expect(finished.usage?.cachedInputTokens, 4);
    });

    test('threads streamed tool calls by index and readies them', () {
      final parser = OpenAiChunkParser();
      final events = [
        ...parser.parse({
          'id': 'c1',
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'id': 'call_a',
                    'function': {'name': 'get_weather', 'arguments': '{"ci'},
                  },
                ],
              },
            },
          ],
        }),
        ...parser.parse({
          'id': 'c1',
          'choices': [
            {
              'delta': {
                'tool_calls': [
                  {
                    'index': 0,
                    'function': {'arguments': 'ty":"London"}'},
                  },
                ],
              },
              'finish_reason': 'tool_calls',
            },
          ],
        }),
        ...parser.finalize(),
      ];

      expect(
        events.whereType<ToolCallStarted>().single.toolName,
        'get_weather',
      );
      expect(events.whereType<ToolCallDelta>().map((e) => e.argumentsDelta), [
        '{"ci',
        'ty":"London"}',
      ]);
      expect(events.whereType<ToolCallReady>().single.toolCallId, 'call_a');
      expect(
        (events.whereType<MessageFinished>().single).reason,
        FinishReason.toolCalls,
      );
    });
  });

  group('OpenAiProvider.send', () {
    test('streams events end-to-end over a mock client', () async {
      final provider = OpenAiProvider(
        apiKey: 'test',
        client: _sseClient([
          'data: ${jsonEncode({
                'id': 'c1',
                'choices': [
                  {
                    'delta': {'content': 'Hi'},
                  },
                ],
              })}',
          'data: ${jsonEncode({
                'id': 'c1',
                'choices': [
                  {
                    'delta': {'content': '!'},
                    'finish_reason': 'stop',
                  },
                ],
              })}',
          'data: [DONE]',
        ]),
      );

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

    test('emits a StreamErrorEvent on a non-200 response', () async {
      final provider = OpenAiProvider(
        apiKey: 'bad',
        client: _sseClient(['nope'], statusCode: 401),
      );
      final events = await provider
          .send(const AiConversation(id: 'c', messages: []))
          .toList();
      final error = events.single as StreamErrorEvent;
      // Typed so hosts can branch on auth vs rate-limit vs server.
      expect(error.error, isA<LlmAuthException>());
    });

    test('emits a StreamErrorEvent when the transport throws', () async {
      final provider = OpenAiProvider(
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

    test('builds the request payload with model, tools, and messages',
        () async {
      late Map<String, Object?> payload;
      late String authHeader;
      final provider = OpenAiProvider(
        apiKey: 'secret',
        client: MockClient.streaming((request, bodyStream) async {
          authHeader = request.headers['authorization'] ?? '';
          final body = await bodyStream.bytesToString();
          payload = (jsonDecode(body) as Map).cast<String, Object?>();
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('data: [DONE]\n')),
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
                  id: 'm1',
                  role: AiRole.user,
                  parts: [TextPart('Hi')],
                ),
              ],
            ),
            tools: [
              const ToolDefinition(
                name: 'get_weather',
                description: 'Look up weather',
                parametersSchema: {'type': 'object'},
              ),
            ],
            options: const AiRequestOptions(model: 'gpt-4o'),
          )
          .toList();

      expect(authHeader, 'Bearer secret');
      expect(payload['model'], 'gpt-4o');
      expect(payload['stream'], true);
      final messages =
          (payload['messages'] as List).cast<Map<String, Object?>>();
      expect(messages.single['role'], 'user');
      expect(messages.single['content'], 'Hi');
      final tools = (payload['tools'] as List).cast<Map<String, Object?>>();
      expect(tools.single['type'], 'function');
      final function =
          (tools.single['function'] as Map).cast<String, Object?>();
      expect(function['name'], 'get_weather');
    });

    test('maps responseFormat to a json_schema response_format', () async {
      late Map<String, Object?> payload;
      final provider = OpenAiProvider(
        apiKey: 'k',
        client: MockClient.streaming((request, bodyStream) async {
          payload = (jsonDecode(await bodyStream.bytesToString()) as Map)
              .cast<String, Object?>();
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('data: [DONE]\n')),
            200,
          );
        }),
      );

      await provider
          .send(
            const AiConversation(
              id: 'c',
              messages: [
                AiMessage(id: 'm', role: AiRole.user, parts: [TextPart('hi')]),
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
                name: 'result',
              ),
            ),
          )
          .toList();

      final rf = (payload['response_format'] as Map).cast<String, Object?>();
      expect(rf['type'], 'json_schema');
      final js = (rf['json_schema'] as Map).cast<String, Object?>();
      expect(js['name'], 'result');
      expect(js['strict'], true);
      expect((js['schema'] as Map)['type'], 'object');
    });

    test('falls back to the default model when options omit one', () async {
      late Map<String, Object?> payload;
      final provider = OpenAiProvider(
        apiKey: 'test',
        client: MockClient.streaming((request, bodyStream) async {
          final body = await bodyStream.bytesToString();
          payload = (jsonDecode(body) as Map).cast<String, Object?>();
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('data: [DONE]\n')),
            200,
          );
        }),
      );

      await provider.send(const AiConversation(id: 'c', messages: [])).toList();

      expect(payload['model'], 'gpt-4o-mini');
    });
  });

  test('encodes image attachments as image_url parts', () async {
    late http.Request captured;
    final provider = OpenAiProvider(
      apiKey: 'k',
      client: MockClient.streaming((request, _) async {
        captured = request as http.Request;
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('data: [DONE]\n')),
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
    final content = (body['messages']! as List).first as Map;
    final parts = content['content']! as List;
    final image =
        parts.firstWhere((p) => (p as Map)['type'] == 'image_url') as Map;
    expect((image['image_url'] as Map)['url'], 'data:image/png;base64,AQID');
  });

  test('emits a StreamErrorEvent on a wrong-shape chunk without throwing',
      () async {
    // Valid JSON, wrong shape: `choices: [null]` makes the parser's cast throw.
    final provider = OpenAiProvider(
      apiKey: 'k',
      client: _sseClient([
        'data: ${jsonEncode({
              'id': 'c1',
              'choices': [null],
            })}',
        'data: ${jsonEncode({
              'id': 'c1',
              'choices': [
                {
                  'delta': {'content': 'ok'},
                  'finish_reason': 'stop',
                },
              ],
            })}',
        'data: [DONE]',
      ]),
    );
    final events = await provider
        .send(const AiConversation(id: 'c', messages: []))
        .toList();
    expect(events.whereType<StreamErrorEvent>(), isNotEmpty);
    // The stream continued past the bad chunk rather than throwing.
    expect(events.whereType<TextDelta>().map((e) => e.delta), contains('ok'));
  });

  test('finalizes a stream that ends without a finish_reason', () async {
    final provider = OpenAiProvider(
      apiKey: 'k',
      client: _sseClient([
        'data: ${jsonEncode({
              'id': 'c1',
              'choices': [
                {
                  'delta': {'content': 'hi'},
                },
              ],
            })}',
      ]),
    );
    final processor = MessageProcessor();
    for (final e in await provider
        .send(const AiConversation(id: 'c', messages: []))
        .toList()) {
      processor.apply(e);
    }
    expect(
      processor.conversation.messages.single.status,
      AiMessageStatus.complete,
    );
  });

  test('surfaces a message-scoped StreamErrorEvent (no finalize) on a stall',
      () async {
    // A body stream that emits one chunk then never completes (no [DONE]),
    // simulating a mid-stream stall. The short idle timeout fires.
    final controller = StreamController<List<int>>();
    controller.add(utf8.encode('data: ${jsonEncode({
          'id': 'c1',
          'choices': [
            {
              'delta': {'content': 'hi'},
            },
          ],
        })}\n'));
    // Never closed — the stream idles forever until the timeout fires.
    final provider = OpenAiProvider(
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
    expect(errors.last.messageId, 'c1'); // marks the in-flight message errored
    // No terminal MessageFinished — that would mask the timeout as success.
    expect(events.whereType<MessageFinished>(), isEmpty);
  });

  test('retries a transient 503 then succeeds', () async {
    var calls = 0;
    final provider = OpenAiProvider(
      apiKey: 'k',
      client: MockClient.streaming((request, _) async {
        calls++;
        if (calls == 1) {
          return http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('busy')),
            503,
          );
        }
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('data: [DONE]\n')),
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

  group('embed', () {
    test('POSTs to /embeddings and maps vectors and indices', () async {
      late http.Request captured;
      late Map<String, Object?> payload;
      final provider = OpenAiProvider(
        apiKey: 'secret',
        client: MockClient((request) async {
          captured = request;
          payload = (jsonDecode(request.body) as Map).cast<String, Object?>();
          return http.Response(
            jsonEncode({
              'object': 'list',
              'data': [
                {
                  'object': 'embedding',
                  'index': 0,
                  'embedding': [0.1, 0.2, 0.3],
                },
                {
                  'object': 'embedding',
                  'index': 1,
                  'embedding': [0.4, 0.5],
                },
              ],
              'model': 'text-embedding-3-small',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final embeddings = await provider.embed(['hello', 'world']);

      expect(captured.url.toString(), endsWith('/embeddings'));
      expect(captured.headers['authorization'], 'Bearer secret');
      expect(payload['model'], 'text-embedding-3-small');
      expect(payload['input'], ['hello', 'world']);
      expect(embeddings, [
        const AiEmbedding([0.1, 0.2, 0.3], index: 0),
        const AiEmbedding([0.4, 0.5], index: 1),
      ]);
    });

    test('honors an explicit model override', () async {
      late Map<String, Object?> payload;
      final provider = OpenAiProvider(
        apiKey: 'k',
        client: MockClient((request) async {
          payload = (jsonDecode(request.body) as Map).cast<String, Object?>();
          return http.Response(jsonEncode({'data': const <Object?>[]}), 200);
        }),
      );

      await provider.embed(['x'], model: 'text-embedding-3-large');

      expect(payload['model'], 'text-embedding-3-large');
    });

    test('throws a typed LlmException on a non-200', () async {
      final provider = OpenAiProvider(
        apiKey: 'k',
        client: MockClient((request) async => http.Response('nope', 401)),
      );

      await expectLater(
        provider.embed(['x']),
        throwsA(isA<LlmAuthException>()),
      );
    });

    test('is discoverable as an EmbeddingProvider at runtime', () {
      final LlmProvider provider = OpenAiProvider(apiKey: 'k');
      expect(provider is EmbeddingProvider, isTrue);
    });
  });
}

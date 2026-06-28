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
      ];

      expect(events[0], isA<MessageStarted>());
      expect(events.whereType<TextDelta>().map((e) => e.delta), [
        'Hello',
        ' world',
      ]);
      expect(events.last, isA<MessageFinished>());
      expect((events.last as MessageFinished).reason, FinishReason.stop);
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
      expect(events.single, isA<StreamErrorEvent>());
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
}

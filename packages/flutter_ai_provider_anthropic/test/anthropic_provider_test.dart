import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_ai_provider_anthropic/flutter_ai_provider_anthropic.dart';
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

/// Wraps [data] objects as `data:` SSE lines (the provider ignores `event:`).
List<String> _dataLines(List<Map<String, Object?>> data) =>
    [for (final d in data) 'data: ${jsonEncode(d)}'];

void main() {
  group('AnthropicEventParser', () {
    test('emits start, text deltas, and finish', () {
      final parser = AnthropicEventParser();
      final events = [
        ...parser.parse({
          'type': 'message_start',
          'message': {'id': 'msg_1', 'role': 'assistant'},
        }),
        ...parser.parse({
          'type': 'content_block_start',
          'index': 0,
          'content_block': {'type': 'text', 'text': ''},
        }),
        ...parser.parse({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'Hello'},
        }),
        ...parser.parse({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': ' world'},
        }),
        ...parser.parse({
          'type': 'message_delta',
          'delta': {'stop_reason': 'end_turn'},
        }),
        ...parser.parse({'type': 'message_stop'}),
      ];

      expect(events.first, isA<MessageStarted>());
      expect((events.first as MessageStarted).messageId, 'msg_1');
      expect(events.whereType<TextDelta>().map((e) => e.delta), [
        'Hello',
        ' world',
      ]);
      expect(events.last, isA<MessageFinished>());
      expect((events.last as MessageFinished).reason, FinishReason.stop);
    });

    test('maps thinking deltas to ReasoningDelta', () {
      final parser = AnthropicEventParser();
      final events = parser.parse({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'thinking_delta', 'thinking': 'Let me reason.'},
      });
      expect(events.single, isA<ReasoningDelta>());
      expect((events.single as ReasoningDelta).delta, 'Let me reason.');
    });

    test('threads streamed tool calls by index and readies them', () {
      final parser = AnthropicEventParser();
      final events = [
        ...parser.parse({
          'type': 'content_block_start',
          'index': 1,
          'content_block': {
            'type': 'tool_use',
            'id': 'toolu_a',
            'name': 'get_weather',
          },
        }),
        ...parser.parse({
          'type': 'content_block_delta',
          'index': 1,
          'delta': {'type': 'input_json_delta', 'partial_json': '{"ci'},
        }),
        ...parser.parse({
          'type': 'content_block_delta',
          'index': 1,
          'delta': {
            'type': 'input_json_delta',
            'partial_json': 'ty":"London"}'
          },
        }),
        ...parser.parse({'type': 'content_block_stop', 'index': 1}),
        ...parser.parse({
          'type': 'message_delta',
          'delta': {'stop_reason': 'tool_use'},
        }),
        ...parser.parse({'type': 'message_stop'}),
      ];

      expect(
          events.whereType<ToolCallStarted>().single.toolName, 'get_weather');
      expect(events.whereType<ToolCallDelta>().map((e) => e.argumentsDelta), [
        '{"ci',
        'ty":"London"}',
      ]);
      expect(events.whereType<ToolCallReady>().single.toolCallId, 'toolu_a');
      expect(
        events.whereType<MessageFinished>().single.reason,
        FinishReason.toolCalls,
      );
    });

    test('maps an error event to StreamErrorEvent', () {
      final parser = AnthropicEventParser();
      final events = parser.parse({
        'type': 'error',
        'error': {'type': 'overloaded_error', 'message': 'Overloaded'},
      });
      expect(events.single, isA<StreamErrorEvent>());
      expect((events.single as StreamErrorEvent).error, 'Overloaded');
    });
  });

  group('AnthropicProvider.send', () {
    test('streams events end-to-end over a mock client', () async {
      final provider = AnthropicProvider(
        apiKey: 'test',
        client: _sseClient([
          'event: message_start',
          ..._dataLines([
            {
              'type': 'message_start',
              'message': {'id': 'msg_1', 'role': 'assistant'},
            },
          ]),
          'event: content_block_delta',
          ..._dataLines([
            {
              'type': 'content_block_delta',
              'index': 0,
              'delta': {'type': 'text_delta', 'text': 'Hi'},
            },
            {
              'type': 'content_block_delta',
              'index': 0,
              'delta': {'type': 'text_delta', 'text': '!'},
            },
            {
              'type': 'message_delta',
              'delta': {'stop_reason': 'end_turn'},
            },
            {'type': 'message_stop'},
          ]),
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
      final provider = AnthropicProvider(
        apiKey: 'bad',
        client: _sseClient(['nope'], statusCode: 401),
      );
      final events = await provider
          .send(const AiConversation(id: 'c', messages: []))
          .toList();
      expect(events.single, isA<StreamErrorEvent>());
    });

    test('sends required headers, max_tokens, and folds system messages',
        () async {
      late http.Request captured;
      final provider = AnthropicProvider(
        apiKey: 'sk-test',
        client: MockClient.streaming((request, bodyStream) async {
          captured = request as http.Request;
          return http.StreamedResponse(
            Stream<List<int>>.value(
              utf8.encode('data: ${jsonEncode({'type': 'message_stop'})}\n'),
            ),
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
                AiMessage(
                  id: 'u',
                  role: AiRole.user,
                  parts: [TextPart('Hi')],
                ),
              ],
            ),
          )
          .toList();

      expect(captured.headers['x-api-key'], 'sk-test');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      final body = (jsonDecode(captured.body) as Map).cast<String, Object?>();
      expect(body['system'], 'Be terse.');
      expect(body['max_tokens'], 4096);
      expect(body['stream'], true);
      final messages = body['messages']! as List;
      expect(messages, hasLength(1)); // system is hoisted out of messages
      expect((messages.single as Map)['role'], 'user');
    });

    test('emits a StreamErrorEvent when the transport throws', () async {
      final provider = AnthropicProvider(
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
      final provider = AnthropicProvider(
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
            Stream<List<int>>.value(
              utf8.encode('data: ${jsonEncode({'type': 'message_stop'})}\n'),
            ),
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
      // Valid JSON, wrong shape: a content_block whose value is a String makes
      // the parser's `as Map?` cast throw; the stream must continue, not die.
      final provider = AnthropicProvider(
        apiKey: 'k',
        client: _sseClient(_dataLines([
          {
            'type': 'message_start',
            'message': {'id': 'msg_1', 'role': 'assistant'},
          },
          {'type': 'content_block_start', 'index': 0, 'content_block': 'oops'},
          {
            'type': 'content_block_delta',
            'index': 0,
            'delta': {'type': 'text_delta', 'text': 'ok'},
          },
          {'type': 'message_stop'},
        ])),
      );
      final events = await provider
          .send(const AiConversation(id: 'c', messages: []))
          .toList();
      expect(events.whereType<StreamErrorEvent>(), isNotEmpty);
      expect(events.whereType<TextDelta>().map((e) => e.delta), contains('ok'));
    });

    test('finalizes a stream that ends without a message_stop', () async {
      final provider = AnthropicProvider(
        apiKey: 'k',
        client: _sseClient(_dataLines([
          {
            'type': 'message_start',
            'message': {'id': 'msg_1', 'role': 'assistant'},
          },
          {
            'type': 'content_block_delta',
            'index': 0,
            'delta': {'type': 'text_delta', 'text': 'hi'},
          },
        ])),
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

    test('emits StreamErrorEvent + MessageFinished when the stream stalls',
        () async {
      final controller = StreamController<List<int>>();
      controller.add(utf8.encode(_dataLines([
        {
          'type': 'message_start',
          'message': {'id': 'msg_1', 'role': 'assistant'},
        },
      ]).map((l) => '$l\n').join()));
      final provider = AnthropicProvider(
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
      expect(events.whereType<StreamErrorEvent>(), isNotEmpty);
      expect(events.whereType<MessageFinished>(), isNotEmpty);
    });

    test('merges adjacent same-role turns so roles alternate', () async {
      late http.Request captured;
      final provider = AnthropicProvider(
        apiKey: 'k',
        client: MockClient.streaming((request, _) async {
          captured = request as http.Request;
          return http.StreamedResponse(
            Stream<List<int>>.value(
              utf8.encode('data: ${jsonEncode({'type': 'message_stop'})}\n'),
            ),
            200,
          );
        }),
      );
      // A normal user turn immediately followed by a tool-result turn (also
      // mapped to role `user`) would otherwise produce two user turns in a row.
      await provider
          .send(
            const AiConversation(
              id: 'c',
              messages: [
                AiMessage(
                  id: 'u',
                  role: AiRole.user,
                  parts: [TextPart('Hi')],
                ),
                AiMessage(
                  id: 't',
                  role: AiRole.tool,
                  parts: [
                    ToolResultPart(
                      toolCallId: 'call_1',
                      result: 'done',
                    ),
                  ],
                ),
              ],
            ),
          )
          .toList();
      final body = (jsonDecode(captured.body) as Map).cast<String, Object?>();
      final messages = (body['messages']! as List).cast<Map<String, Object?>>();
      expect(messages, hasLength(1));
      expect(messages.single['role'], 'user');
      // Both the text and the tool_result are concatenated into one content[].
      final content = messages.single['content'] as List;
      expect(content.any((p) => (p as Map)['type'] == 'text'), isTrue);
      expect(content.any((p) => (p as Map)['type'] == 'tool_result'), isTrue);
    });
  });

  test('encodes image attachments as base64 image blocks', () async {
    late http.Request captured;
    final provider = AnthropicProvider(
      apiKey: 'k',
      client: MockClient.streaming((request, _) async {
        captured = request as http.Request;
        return http.StreamedResponse(
          Stream<List<int>>.value(
              utf8.encode('data: {"type":"message_stop"}\n')),
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
    final content =
        ((body['messages']! as List).first as Map)['content'] as List;
    final image =
        content.firstWhere((p) => (p as Map)['type'] == 'image') as Map;
    final source = image['source'] as Map;
    expect(source['media_type'], 'image/png');
    expect(source['data'], 'AQID');
  });
}

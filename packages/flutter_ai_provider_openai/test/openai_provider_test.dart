import 'dart:convert';

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
  });
}

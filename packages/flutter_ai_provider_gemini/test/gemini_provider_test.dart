import 'dart:convert';

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
        }),
      ];

      expect(events.first, isA<MessageStarted>());
      expect(events.whereType<TextDelta>().map((e) => e.delta), [
        'Hello',
        ' world',
      ]);
      expect(events.last, isA<MessageFinished>());
      expect((events.last as MessageFinished).reason, FinishReason.stop);
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
  });
}

import 'dart:typed_data';

import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('enum JSON', () {
    test('AiRole round-trips and rejects unknown values', () {
      for (final role in AiRole.values) {
        expect(AiRole.fromJson(role.toJson()), role);
      }
      expect(() => AiRole.fromJson('nope'), throwsFormatException);
    });

    test('FinishReason round-trips with hyphenated wire names', () {
      expect(FinishReason.toolCalls.toJson(), 'tool-calls');
      expect(FinishReason.fromJson('tool-calls'), FinishReason.toolCalls);
      expect(() => FinishReason.fromJson('x'), throwsFormatException);
    });

    test('ToolCallState round-trips', () {
      for (final state in ToolCallState.values) {
        expect(ToolCallState.fromJson(state.toJson()), state);
      }
    });
  });

  group('AiPart', () {
    test('TextPart round-trips and compares by value', () {
      const part = TextPart('hello');
      expect(AiPart.fromJson(part.toJson()), part);
      expect(part, const TextPart('hello'));
      expect(part.copyWith(text: 'hi'), const TextPart('hi'));
    });

    test('ToolCallPart preserves args with deep equality', () {
      const part = ToolCallPart(
        toolCallId: 'c1',
        toolName: 'search',
        args: {
          'query': 'flutter',
          'filters': ['recent', 'open'],
        },
        state: ToolCallState.inputAvailable,
      );
      final decoded = AiPart.fromJson(part.toJson());
      expect(decoded, part);
      expect(decoded.hashCode, part.hashCode);
    });

    test('FilePart round-trips inline bytes via base64', () {
      final part = FilePart(
        mediaType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3, 250]),
        name: 'pixel.png',
      );
      final decoded = AiPart.fromJson(part.toJson()) as FilePart;
      expect(decoded.bytes, part.bytes);
      expect(decoded, part);
    });

    test('FilePart round-trips a url', () {
      final part = FilePart(
        mediaType: 'application/pdf',
        url: Uri.parse('https://example.com/a.pdf'),
      );
      expect(AiPart.fromJson(part.toJson()), part);
    });

    test('SourcePart and DataPart round-trip', () {
      final source = SourcePart(url: Uri.parse('https://x.test'), title: 'X');
      expect(AiPart.fromJson(source.toJson()), source);

      const data = DataPart(dataType: 'weather_card', data: {'tempC': 21});
      expect(AiPart.fromJson(data.toJson()), data);
    });

    test('fromJson rejects an unknown type', () {
      expect(
        () => AiPart.fromJson({'type': 'mystery'}),
        throwsFormatException,
      );
    });
  });

  group('AiMessage', () {
    test('text getter concatenates only TextParts', () {
      const message = AiMessage(
        id: 'm1',
        role: AiRole.assistant,
        parts: [
          TextPart('Hello '),
          ReasoningPart('thinking'),
          TextPart('world'),
        ],
      );
      expect(message.text, 'Hello world');
    });

    test('round-trips including finishReason and createdAt', () {
      final message = AiMessage(
        id: 'm1',
        role: AiRole.assistant,
        parts: const [TextPart('hi')],
        status: AiMessageStatus.complete,
        finishReason: FinishReason.stop,
        createdAt: DateTime.utc(2026, 6, 26, 12),
      );
      expect(AiMessage.fromJson(message.toJson()), message);
    });

    test('text convenience constructor builds a single TextPart', () {
      final message = AiMessage.text(
        id: 'm1',
        role: AiRole.user,
        text: 'hey',
      );
      expect(message.parts, const [TextPart('hey')]);
    });

    test('copyWith replaces only provided fields', () {
      const message = AiMessage(id: 'm1', role: AiRole.user);
      final updated = message.copyWith(status: AiMessageStatus.streaming);
      expect(updated.id, 'm1');
      expect(updated.role, AiRole.user);
      expect(updated.status, AiMessageStatus.streaming);
    });
  });

  group('AiConversation', () {
    const m1 = AiMessage(id: 'm1', role: AiRole.user, parts: [TextPart('hi')]);
    const m2 = AiMessage(id: 'm2', role: AiRole.assistant);

    test('append and messageById', () {
      const convo = AiConversation.empty('c1');
      final next = convo.append(m1);
      expect(next.messages, [m1]);
      expect(next.messageById('m1'), m1);
      expect(next.messageById('absent'), isNull);
      expect(next.lastMessage, m1);
    });

    test('replace upserts by id', () {
      const convo = AiConversation(id: 'c1', messages: [m1, m2]);
      final edited = m1.copyWith(parts: const [TextPart('edited')]);
      final next = convo.replace(edited);
      expect(next.messages.length, 2);
      expect(next.messageById('m1')!.text, 'edited');

      const m3 = AiMessage(id: 'm3', role: AiRole.user);
      expect(convo.replace(m3).messages.last, m3);
    });

    test('round-trips through JSON', () {
      const convo = AiConversation(id: 'c1', messages: [m1, m2]);
      expect(AiConversation.fromJson(convo.toJson()), convo);
    });
  });

  group('ToolDefinition', () {
    test('round-trips with a JSON schema', () {
      const tool = ToolDefinition(
        name: 'get_weather',
        description: 'Get weather for a city',
        parametersSchema: {
          'type': 'object',
          'properties': {
            'city': {'type': 'string'},
          },
        },
      );
      expect(ToolDefinition.fromJson(tool.toJson()), tool);
    });
  });

  group('AiRequestOptions', () {
    test('copyWith and value equality', () {
      const options = AiRequestOptions(model: 'gpt-4o', temperature: 0.7);
      expect(options.copyWith(model: 'gpt-4o-mini').model, 'gpt-4o-mini');
      expect(options.copyWith(model: 'gpt-4o-mini').temperature, 0.7);
      expect(
        const AiRequestOptions(model: 'gpt-4o', temperature: 0.7),
        options,
      );
    });
  });
}

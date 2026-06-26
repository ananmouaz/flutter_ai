import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('AiStreamEvent JSON round-trips', () {
    final events = <AiStreamEvent>[
      const MessageStarted(messageId: 'm1', role: AiRole.assistant),
      const TextDelta(messageId: 'm1', delta: 'hello'),
      const ReasoningDelta(messageId: 'm1', delta: 'because'),
      const ToolCallStarted(
        messageId: 'm1',
        toolCallId: 'c1',
        toolName: 'search',
      ),
      const ToolCallDelta(toolCallId: 'c1', argumentsDelta: '{"q":'),
      const ToolCallReady(toolCallId: 'c1'),
      const ToolResultReceived(
        messageId: 'm1',
        toolCallId: 'c1',
        result: {'hits': 3},
      ),
      const PartReceived(
        messageId: 'm1',
        part: DataPart(dataType: 'card', data: {'k': 'v'}),
      ),
      const MessageFinished(messageId: 'm1', reason: FinishReason.stop),
      const StreamErrorEvent(error: 'boom', messageId: 'm1', toolCallId: 'c1'),
    ];

    for (final event in events) {
      test('${event.runtimeType}', () {
        final decoded = AiStreamEvent.fromJson(event.toJson());
        expect(decoded, event);
        expect(decoded.runtimeType, event.runtimeType);
      });
    }

    test('rejects an unknown event type', () {
      expect(
        () => AiStreamEvent.fromJson({'type': 'unknown'}),
        throwsFormatException,
      );
    });

    test('error event restores the message form of the error', () {
      const event = StreamErrorEvent(error: 'boom');
      final decoded = AiStreamEvent.fromJson(event.toJson());
      expect(decoded, event);
    });
  });
}

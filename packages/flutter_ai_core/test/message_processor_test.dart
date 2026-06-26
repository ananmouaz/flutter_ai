import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('MessageProcessor text streaming', () {
    test('concatenates text deltas into one part', () {
      final processor = MessageProcessor();
      processor.apply(
        const MessageStarted(messageId: 'm1', role: AiRole.assistant),
      );
      processor.apply(const TextDelta(messageId: 'm1', delta: 'Hel'));
      final result = processor.apply(
        const TextDelta(messageId: 'm1', delta: 'lo'),
      );

      final message = result.conversation.messageById('m1')!;
      expect(message.parts, const [TextPart('Hello')]);
      expect(message.status, AiMessageStatus.streaming);
      expect(result.changedMessageIds, {'m1'});
    });

    test('auto-creates an assistant message without a start event', () {
      final processor = MessageProcessor();
      processor.apply(const TextDelta(messageId: 'm1', delta: 'hi'));
      final message = processor.conversation.messageById('m1')!;
      expect(message.role, AiRole.assistant);
      expect(message.text, 'hi');
    });

    test('finishing sets status and finishReason', () {
      final processor = MessageProcessor();
      processor.apply(const TextDelta(messageId: 'm1', delta: 'done'));
      processor.apply(
        const MessageFinished(messageId: 'm1', reason: FinishReason.stop),
      );
      final message = processor.conversation.messageById('m1')!;
      expect(message.status, AiMessageStatus.complete);
      expect(message.finishReason, FinishReason.stop);
    });

    test('reasoning deltas accumulate in a ReasoningPart', () {
      final processor = MessageProcessor();
      processor.apply(const ReasoningDelta(messageId: 'm1', delta: 'be'));
      processor.apply(const ReasoningDelta(messageId: 'm1', delta: 'cause'));
      final part = processor.conversation.messageById('m1')!.parts.single;
      expect(part, const ReasoningPart('because'));
    });
  });

  group('MessageProcessor tool calls', () {
    test('streams arguments then validates on ready', () {
      final processor = MessageProcessor();
      processor.apply(
        const ToolCallStarted(
          messageId: 'm1',
          toolCallId: 'c1',
          toolName: 'get_weather',
        ),
      );
      processor.apply(
        const ToolCallDelta(toolCallId: 'c1', argumentsDelta: '{"city":"Lon'),
      );

      var call = _firstToolCall(processor);
      expect(call.state, ToolCallState.inputStreaming);

      processor.apply(
        const ToolCallDelta(toolCallId: 'c1', argumentsDelta: 'don"}'),
      );
      processor.apply(const ToolCallReady(toolCallId: 'c1'));

      call = _firstToolCall(processor);
      expect(call.state, ToolCallState.inputAvailable);
      expect(call.args, {'city': 'London'});
    });

    test('appends a result and advances the call state', () {
      final processor = MessageProcessor();
      processor.apply(
        const ToolCallStarted(
          messageId: 'm1',
          toolCallId: 'c1',
          toolName: 'get_weather',
        ),
      );
      processor.apply(
        const ToolResultReceived(
          messageId: 'm1',
          toolCallId: 'c1',
          result: {'tempC': 21},
        ),
      );

      final message = processor.conversation.messageById('m1')!;
      expect(_firstToolCall(processor).state, ToolCallState.outputAvailable);
      final resultPart = message.parts.whereType<ToolResultPart>().single;
      expect(resultPart.result, {'tempC': 21});
      expect(resultPart.isError, isFalse);
    });

    test('malformed arguments mark the call errored without throwing', () {
      final processor = MessageProcessor();
      processor.apply(
        const ToolCallStarted(
          messageId: 'm1',
          toolCallId: 'c1',
          toolName: 'broken',
        ),
      );
      processor.apply(
        const ToolCallDelta(toolCallId: 'c1', argumentsDelta: '{not json'),
      );

      expect(
        () => processor.apply(const ToolCallReady(toolCallId: 'c1')),
        returnsNormally,
      );

      final message = processor.conversation.messageById('m1')!;
      expect(_firstToolCall(processor).state, ToolCallState.error);
      final errorResult = message.parts.whereType<ToolResultPart>().single;
      expect(errorResult.isError, isTrue);
    });

    test('a delta for an unknown call is a no-op', () {
      final processor = MessageProcessor();
      final result = processor.apply(
        const ToolCallDelta(toolCallId: 'ghost', argumentsDelta: '{}'),
      );
      expect(result.hasChanges, isFalse);
      expect(result.conversation.messages, isEmpty);
    });
  });

  group('MessageProcessor errors and lifecycle', () {
    test('scoped stream error marks the message errored', () {
      final processor = MessageProcessor();
      processor.apply(const TextDelta(messageId: 'm1', delta: 'partial'));
      processor.apply(
        const StreamErrorEvent(error: 'boom', messageId: 'm1'),
      );
      expect(
        processor.conversation.messageById('m1')!.status,
        AiMessageStatus.error,
      );
    });

    test('an unscoped stream error changes nothing', () {
      final processor = MessageProcessor();
      final result =
          processor.apply(const StreamErrorEvent(error: 'transport down'));
      expect(result.hasChanges, isFalse);
    });

    test('reset restores a seed conversation and clears scratch state', () {
      final processor = MessageProcessor();
      processor.apply(const TextDelta(messageId: 'm1', delta: 'hi'));
      processor.reset(const AiConversation.empty('fresh'));
      expect(processor.conversation.id, 'fresh');
      expect(processor.conversation.messages, isEmpty);
    });

    test('seeds from an existing conversation', () {
      const seed = AiConversation(
        id: 'c1',
        messages: [
          AiMessage(id: 'm1', role: AiRole.user, parts: [TextPart('q')]),
        ],
      );
      final processor = MessageProcessor(conversation: seed);
      processor.apply(const TextDelta(messageId: 'm2', delta: 'a'));
      expect(processor.conversation.messages.map((m) => m.id), ['m1', 'm2']);
    });
  });
}

ToolCallPart _firstToolCall(MessageProcessor processor) =>
    processor.conversation.messages
        .expand((m) => m.parts)
        .whereType<ToolCallPart>()
        .first;

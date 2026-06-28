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

  group('MessageProcessor tool fixes', () {
    ToolCallPart callOf(MutationResult r, String mid, String cid) =>
        r.conversation
            .messageById(mid)!
            .parts
            .whereType<ToolCallPart>()
            .firstWhere((p) => p.toolCallId == cid);

    test('a zero-argument tool call becomes inputAvailable, not error', () {
      final processor = MessageProcessor();
      processor.apply(
        const MessageStarted(messageId: 'm1', role: AiRole.assistant),
      );
      processor.apply(
        const ToolCallStarted(
          messageId: 'm1',
          toolCallId: 'c1',
          toolName: 'refresh',
        ),
      );
      final r = processor.apply(const ToolCallReady(toolCallId: 'c1'));
      final call = callOf(r, 'm1', 'c1');
      expect(call.state, ToolCallState.inputAvailable);
      expect(call.args, isEmpty);
      expect(
        r.conversation.messageById('m1')!.parts.whereType<ToolResultPart>(),
        isEmpty,
      );
    });

    test('a result in a separate message advances the call to outputAvailable',
        () {
      final processor = MessageProcessor();
      processor.apply(
        const MessageStarted(messageId: 'a1', role: AiRole.assistant),
      );
      processor.apply(
        const ToolCallStarted(
          messageId: 'a1',
          toolCallId: 'c1',
          toolName: 'get_weather',
        ),
      );
      processor.apply(const ToolCallReady(toolCallId: 'c1'));
      // Result arrives in a separate tool-role message (as addToolResults does).
      final r = processor.apply(
        const ToolResultReceived(
          messageId: 't1',
          toolCallId: 'c1',
          result: {'tempC': 18},
        ),
      );
      expect(callOf(r, 'a1', 'c1').state, ToolCallState.outputAvailable);
    });

    test('a tool-scoped error marks only the call, not the whole message', () {
      final processor = MessageProcessor();
      processor.apply(
        const MessageStarted(messageId: 'a1', role: AiRole.assistant),
      );
      processor.apply(
        const ToolCallStarted(
          messageId: 'a1',
          toolCallId: 'c1',
          toolName: 'get_weather',
        ),
      );
      final r = processor.apply(
        const StreamErrorEvent(error: 'tool failed', toolCallId: 'c1'),
      );
      final message = r.conversation.messageById('a1')!;
      expect(callOf(r, 'a1', 'c1').state, ToolCallState.error);
      expect(message.status, AiMessageStatus.streaming); // message not killed
    });
  });
}

/// The first tool call across the processor's conversation.
ToolCallPart _firstToolCall(MessageProcessor processor) =>
    processor.conversation.messages
        .expand((m) => m.parts)
        .whereType<ToolCallPart>()
        .first;

import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// A scripted [LlmProvider] that always streams the same rich response —
/// reasoning, a tool call with a result, prose, and a citation — so the chat
/// UI exercises every element without a real backend.
class DemoChatProvider implements LlmProvider {
  /// Creates a demo provider with a per-event [delay] for a streaming feel.
  const DemoChatProvider({this.delay = const Duration(milliseconds: 120)});

  /// Delay between emitted events.
  final Duration delay;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    const id = 'assistant';
    Future<AiStreamEvent> step(AiStreamEvent event) async {
      await Future<void>.delayed(delay);
      return event;
    }

    yield const MessageStarted(messageId: id, role: AiRole.assistant);
    yield await step(
      const ReasoningDelta(
        messageId: id,
        delta: 'The user wants current weather — call the weather tool.',
      ),
    );
    yield await step(
      const TextDelta(messageId: id, delta: 'Let me check the weather '),
    );
    yield await step(const TextDelta(messageId: id, delta: 'for you.'));

    yield await step(
      const ToolCallStarted(
        messageId: id,
        toolCallId: 'call_1',
        toolName: 'get_weather',
      ),
    );
    yield await step(
      const ToolCallDelta(toolCallId: 'call_1', argumentsDelta: '{"city":'),
    );
    yield await step(
      const ToolCallDelta(toolCallId: 'call_1', argumentsDelta: '"London"}'),
    );
    yield await step(const ToolCallReady(toolCallId: 'call_1'));
    yield await step(
      const ToolResultReceived(
        messageId: id,
        toolCallId: 'call_1',
        result: {'tempC': 18, 'condition': 'Rainy'},
      ),
    );

    for (final word in "It's 18°C and rainy in London — bring an umbrella!"
        .split(' ')) {
      yield await step(TextDelta(messageId: id, delta: '$word '));
    }

    yield await step(
      PartReceived(
        messageId: id,
        part: SourcePart(
          url: Uri.parse('https://weather.example.com/london'),
          title: 'weather.example.com',
        ),
      ),
    );
    yield await step(
      const MessageFinished(messageId: id, reason: FinishReason.stop),
    );
  }
}

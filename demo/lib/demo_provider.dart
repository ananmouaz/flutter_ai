import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// A scripted [LlmProvider] that streams a rich response exercising many
/// elements — reasoning, a tool call with a result, prose, a fenced code block,
/// and citations — with no real backend. If the prompt mentions "error", it
/// streams a failure instead, to demo the error path.
class DemoChatProvider implements LlmProvider {
  /// Creates a demo provider with a per-event [delay] for a streaming feel.
  const DemoChatProvider({this.delay = const Duration(milliseconds: 95)});

  /// Delay between emitted events.
  final Duration delay;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    const id = 'assistant';
    final prompt = conversation.lastMessage?.text.toLowerCase() ?? '';

    Future<AiStreamEvent> step(AiStreamEvent event) async {
      await Future<void>.delayed(delay);
      return event;
    }

    yield const MessageStarted(messageId: id, role: AiRole.assistant);

    if (prompt.contains('error')) {
      yield await step(
        const ReasoningDelta(messageId: id, delta: 'Attempting the request…'),
      );
      yield await step(
        const StreamErrorEvent(
          error: 'The upstream service timed out. Please try again.',
          messageId: id,
        ),
      );
      return;
    }

    yield await step(
      const ReasoningDelta(
        messageId: id,
        delta: "I'll confirm the current best practice and show a short "
            'example.',
      ),
    );
    yield await step(
      const TextDelta(messageId: id, delta: 'Sure — let me check the latest '
          'guidance. '),
    );

    // A tool call with streamed arguments and a result.
    yield await step(
      const ToolCallStarted(
        messageId: id,
        toolCallId: 't1',
        toolName: 'web_search',
      ),
    );
    yield await step(
      const ToolCallDelta(toolCallId: 't1', argumentsDelta: '{"query":'),
    );
    yield await step(
      const ToolCallDelta(
        toolCallId: 't1',
        argumentsDelta: '"flutter stream tokens"}',
      ),
    );
    yield await step(const ToolCallReady(toolCallId: 't1'));
    yield await step(
      const ToolResultReceived(
        messageId: id,
        toolCallId: 't1',
        result: {'results': 3},
      ),
    );

    // The answer: prose + a fenced code block (rendered by DemoTextRenderer).
    yield await step(
      const TextDelta(
        messageId: id,
        delta: "Here's the idiomatic approach — fold the provider's event "
            'stream:\n\n',
      ),
    );
    yield await step(
      const TextDelta(
        messageId: id,
        delta: '```dart\n'
            'await for (final event in provider.send(conversation)) {\n'
            '  processor.apply(event);\n'
            '}\n'
            '```\n\n',
      ),
    );
    yield await step(
      const TextDelta(
        messageId: id,
        delta: 'This keeps the UI at 60fps by rebuilding only the messages '
            'that changed.',
      ),
    );

    // Citations.
    yield await step(
      PartReceived(
        messageId: id,
        part: SourcePart(
          url: Uri.parse('https://docs.flutter.dev/ai'),
          title: 'docs.flutter.dev',
        ),
      ),
    );
    yield await step(
      PartReceived(
        messageId: id,
        part: SourcePart(
          url: Uri.parse('https://pub.dev/packages/flutter_ai_elements'),
          title: 'pub.dev',
        ),
      ),
    );

    yield await step(
      const MessageFinished(messageId: id, reason: FinishReason.stop),
    );
  }
}

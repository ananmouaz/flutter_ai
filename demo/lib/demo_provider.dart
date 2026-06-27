import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// A scripted [LlmProvider] that streams a kitchen-sink agent response so every
/// element appears in one flow: chain of thought, a task list, a tool call, a
/// Markdown answer with a code block, a generated image, and citations.
///
/// Structured widgets ride along as `DataPart`s; the demo's `messageBuilder`
/// maps them to elements (a tiny generative-UI catalog). An "error" prompt
/// streams a failure instead.
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

    // Chain of thought.
    yield await step(
      const PartReceived(
        messageId: id,
        part: DataPart(
          dataType: 'chain_of_thought',
          data: {
            'steps': [
              {'label': 'Locate the controller', 'detail': 'flutter_ai_client'},
              {'label': 'Read use_chat_controller.dart', 'detail': '~210 lines'},
              {'label': 'Plan the change', 'active': true},
            ],
          },
        ),
      ),
    );

    yield await step(
      const TextDelta(messageId: id, delta: "I'll work through these steps:"),
    );

    // Task list.
    yield await step(
      const PartReceived(
        messageId: id,
        part: DataPart(
          dataType: 'task',
          data: {
            'title': 'Refactor plan',
            'items': [
              {'label': 'Extract _startStream()', 'status': 'complete'},
              {'label': 'Harden error handling', 'status': 'active'},
              {'label': 'Update tests', 'status': 'pending'},
            ],
          },
        ),
      ),
    );

    // Tool call.
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

    // Markdown answer with a fenced code block.
    yield await step(
      const TextDelta(
        messageId: id,
        delta: '### Result\n\nFold the provider stream with a reducer:\n\n',
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
        delta: 'This rebuilds **only changed messages**, staying at `60fps`.',
      ),
    );

    // A generated image (loads on-device).
    yield await step(
      PartReceived(
        messageId: id,
        part: FilePart(
          mediaType: 'image/jpeg',
          url: Uri.parse('https://picsum.photos/seed/flutterai/640/360'),
          name: 'diagram.jpg',
        ),
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

// Demonstrates folding a provider's event stream into conversation state with
// MessageProcessor, including streamed tool-call arguments.
//
// Run with: dart run example/flutter_ai_core_example.dart
import 'package:flutter_ai_core/flutter_ai_core.dart';

/// A trivial in-memory provider that replays a scripted stream of events.
///
/// A real provider would translate an SSE / gRPC / local-callback protocol into
/// these same [AiStreamEvent]s.
class ScriptedProvider implements LlmProvider {
  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    const id = 'assistant-1';
    yield const MessageStarted(messageId: id, role: AiRole.assistant);
    yield const TextDelta(messageId: id, delta: 'Let me check the weather. ');

    // A tool call whose arguments stream in as partial JSON.
    yield const ToolCallStarted(
      messageId: id,
      toolCallId: 'call-1',
      toolName: 'get_weather',
    );
    yield const ToolCallDelta(toolCallId: 'call-1', argumentsDelta: '{"city":');
    yield const ToolCallDelta(
      toolCallId: 'call-1',
      argumentsDelta: '"London"}',
    );
    yield const ToolCallReady(toolCallId: 'call-1');

    // The tool result, then the model's final answer.
    yield const ToolResultReceived(
      messageId: id,
      toolCallId: 'call-1',
      result: {'tempC': 21, 'condition': 'Cloudy'},
    );
    yield const TextDelta(messageId: id, delta: "It's 21°C and cloudy.");
    yield const MessageFinished(messageId: id, reason: FinishReason.stop);
  }
}

Future<void> main() async {
  final processor = MessageProcessor(
    conversation: const AiConversation(
      id: 'demo',
      messages: [
        AiMessage(
          id: 'user-1',
          role: AiRole.user,
          parts: [TextPart('What is the weather in London?')],
        ),
      ],
    ),
  );

  final provider = ScriptedProvider();
  await for (final event in provider.send(processor.conversation)) {
    final result = processor.apply(event);
    // A UI would batch these changed ids to the frame boundary; here we just
    // log them to show the granularity.
    if (result.hasChanges) {
      print('changed: ${result.changedMessageIds}');
    }
  }

  print('\n--- final transcript ---');
  for (final message in processor.conversation.messages) {
    print('${message.role.name}: ${_describe(message)}');
  }
}

String _describe(AiMessage message) {
  final buffer = StringBuffer();
  for (final part in message.parts) {
    switch (part) {
      case TextPart(:final text):
        buffer.write(text);
      case ToolCallPart(:final toolName, :final args, :final state):
        buffer.write('[tool $toolName($args) ${state.name}] ');
      case ToolResultPart(:final result):
        buffer.write('[result $result] ');
      case ReasoningPart() || FilePart() || SourcePart() || DataPart():
        buffer.write('[${part.runtimeType}] ');
    }
  }
  return buffer.toString();
}

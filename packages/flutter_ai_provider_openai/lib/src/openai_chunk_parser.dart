import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Translates OpenAI Chat Completions streaming chunks into [AiStreamEvent]s.
///
/// Stateful across a single response: it tracks whether the message has started
/// and maps each streamed tool call's `index` to its `id` (later argument
/// fragments arrive carrying only the index). Kept separate from transport so it
/// can be unit-tested against recorded chunks.
class OpenAiChunkParser {
  bool _started = false;
  bool _finished = false;
  String _messageId = 'assistant';
  final Map<int, String> _toolCallIdByIndex = {};

  /// Emits a terminal [MessageFinished] if the stream ended after starting but
  /// without a `finish_reason` (e.g. a dropped connection or missing `[DONE]`),
  /// so the message isn't left streaming forever. Call once after the stream.
  List<AiStreamEvent> finalize() => _started && !_finished
      ? [MessageFinished(messageId: _messageId, reason: FinishReason.stop)]
      : const [];

  /// Returns the events implied by one decoded `chat.completion.chunk`.
  List<AiStreamEvent> parse(Map<String, Object?> chunk) {
    final events = <AiStreamEvent>[];

    final id = chunk['id'];
    if (id is String && id.isNotEmpty) _messageId = id;
    if (!_started) {
      _started = true;
      events.add(MessageStarted(messageId: _messageId, role: AiRole.assistant));
    }

    final choices = chunk['choices'];
    if (choices is! List || choices.isEmpty) return events;
    final choice = (choices.first as Map).cast<String, Object?>();
    final delta =
        (choice['delta'] as Map?)?.cast<String, Object?>() ?? const {};

    final content = delta['content'];
    if (content is String && content.isNotEmpty) {
      events.add(TextDelta(messageId: _messageId, delta: content));
    }

    final toolCalls = delta['tool_calls'];
    if (toolCalls is List) {
      for (final raw in toolCalls) {
        events.addAll(_parseToolCall((raw as Map).cast<String, Object?>()));
      }
    }

    final finishReason = choice['finish_reason'];
    if (finishReason is String) {
      _finished = true;
      if (finishReason == 'tool_calls') {
        for (final toolCallId in _toolCallIdByIndex.values) {
          events.add(ToolCallReady(toolCallId: toolCallId));
        }
      }
      events.add(
        MessageFinished(
          messageId: _messageId,
          reason: _mapFinish(finishReason),
        ),
      );
    }

    return events;
  }

  List<AiStreamEvent> _parseToolCall(Map<String, Object?> toolCall) {
    final events = <AiStreamEvent>[];
    final index = (toolCall['index'] as num?)?.toInt() ?? 0;
    final function = (toolCall['function'] as Map?)?.cast<String, Object?>();
    final callId = toolCall['id'] as String?;
    final name = function?['name'] as String?;
    final arguments = function?['arguments'] as String?;

    if (callId != null &&
        name != null &&
        !_toolCallIdByIndex.containsKey(index)) {
      _toolCallIdByIndex[index] = callId;
      events.add(
        ToolCallStarted(
          messageId: _messageId,
          toolCallId: callId,
          toolName: name,
        ),
      );
    }

    final resolvedId = _toolCallIdByIndex[index];
    if (resolvedId != null && arguments != null && arguments.isNotEmpty) {
      events.add(
        ToolCallDelta(toolCallId: resolvedId, argumentsDelta: arguments),
      );
    }
    return events;
  }

  static FinishReason _mapFinish(String reason) => switch (reason) {
        'stop' => FinishReason.stop,
        'length' => FinishReason.length,
        'tool_calls' => FinishReason.toolCalls,
        'content_filter' => FinishReason.contentFilter,
        _ => FinishReason.stop,
      };
}

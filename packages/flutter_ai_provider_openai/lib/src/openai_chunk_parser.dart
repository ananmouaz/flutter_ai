import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Translates OpenAI Chat Completions streaming chunks into [AiStreamEvent]s.
///
/// Stateful across a single response: it tracks whether the message has started
/// and maps each streamed tool call's `index` to its `id` (later argument
/// fragments arrive carrying only the index). Kept separate from transport so it
/// can be unit-tested against recorded chunks.
class OpenAiChunkParser {
  bool _started = false;
  bool _emitted = false;
  String _messageId = 'assistant';
  String _finishReason = 'stop';
  AiUsage? _usage;
  final Map<int, String> _toolCallIdByIndex = {};
  final Set<String> _readied = {};

  /// The id of the assistant message being built (for error finalization).
  String get messageId => _messageId;

  /// Emits a [ToolCallReady] for each accumulated tool call not yet readied.
  List<AiStreamEvent> _readyPendingToolCalls() => [
        for (final id in _toolCallIdByIndex.values)
          if (_readied.add(id)) ToolCallReady(toolCallId: id),
      ];

  /// Emits the terminal [MessageFinished]. The finish event is deferred to here
  /// because, with `stream_options.include_usage`, OpenAI sends token usage in a
  /// trailing chunk *after* the `finish_reason` chunk. Call once after the
  /// stream completes (also covers a dropped connection with no `finish_reason`).
  List<AiStreamEvent> finalize() {
    if (!_started || _emitted) return const [];
    _emitted = true;
    return [
      ..._readyPendingToolCalls(),
      MessageFinished(
        messageId: _messageId,
        reason: _mapFinish(_finishReason),
        usage: _usage,
      ),
    ];
  }

  /// Returns the events implied by one decoded `chat.completion.chunk`.
  List<AiStreamEvent> parse(Map<String, Object?> chunk) {
    final events = <AiStreamEvent>[];

    final id = chunk['id'];
    if (id is String && id.isNotEmpty) _messageId = id;
    if (!_started) {
      _started = true;
      events.add(MessageStarted(messageId: _messageId, role: AiRole.assistant));
    }

    // A mid-stream error object (server error, rate limit) replaces the normal
    // choices payload; surface it instead of letting finalize() emit a
    // synthetic success. `_emitted` suppresses that terminal event.
    final error = chunk['error'];
    if (error is Map) {
      _emitted = true;
      final message = error['message'] as String? ?? 'OpenAI stream error';
      events.add(StreamErrorEvent(error: message, messageId: _messageId));
      return events;
    }

    // Usage arrives on its own trailing chunk (empty `choices`); on every other
    // chunk the field is null. Capture it before the empty-choices early return.
    final usage = chunk['usage'];
    if (usage is Map) {
      _usage = _mapUsage(usage.cast<String, Object?>()) ?? _usage;
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
      _finishReason = finishReason;
      // Ready any accumulated tool calls regardless of finish reason — some
      // OpenAI-compatible servers end with `stop` even when tool calls streamed.
      events.addAll(_readyPendingToolCalls());
      // MessageFinished is deferred to finalize() so it can carry usage from the
      // trailing chunk.
    }

    return events;
  }

  static AiUsage? _mapUsage(Map<String, Object?> u) {
    final prompt = u['prompt_tokens'] as int?;
    final completion = u['completion_tokens'] as int?;
    if (prompt == null && completion == null) return null;
    final promptDetails =
        (u['prompt_tokens_details'] as Map?)?.cast<String, Object?>();
    final completionDetails =
        (u['completion_tokens_details'] as Map?)?.cast<String, Object?>();
    return AiUsage(
      inputTokens: prompt,
      outputTokens: completion,
      totalTokens: u['total_tokens'] as int?,
      cachedInputTokens: promptDetails?['cached_tokens'] as int?,
      reasoningTokens: completionDetails?['reasoning_tokens'] as int?,
    );
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

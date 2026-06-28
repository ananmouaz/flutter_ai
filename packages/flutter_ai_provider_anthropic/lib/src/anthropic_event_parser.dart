import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Translates Anthropic Messages API streaming events into [AiStreamEvent]s.
///
/// Stateful across a single response: it tracks the message id, maps each
/// content block's `index` to a streamed tool call's id (later
/// `input_json_delta` fragments arrive carrying only the index), and remembers
/// the final `stop_reason` reported on `message_delta`. Kept separate from
/// transport so it can be unit-tested against recorded SSE events.
///
/// Recognized event `type`s: `message_start`, `content_block_start`,
/// `content_block_delta` (text / thinking / tool-input), `content_block_stop`,
/// `message_delta`, `message_stop`, and `error`. `ping` and unknown types are
/// ignored.
class AnthropicEventParser {
  String _messageId = 'assistant';
  final Map<int, String> _toolCallIdByIndex = {};
  String _stopReason = 'end_turn';
  bool _started = false;
  bool _finished = false;

  /// Emits a terminal [MessageFinished] if the stream ended after starting but
  /// without a `message_stop` (e.g. a dropped connection), so the message isn't
  /// left streaming forever. Call once after the SSE stream completes.
  List<AiStreamEvent> finalize() => _started && !_finished
      ? [
          MessageFinished(
              messageId: _messageId, reason: _mapFinish(_stopReason))
        ]
      : const [];

  /// Returns the events implied by one decoded Anthropic stream event.
  List<AiStreamEvent> parse(Map<String, Object?> event) {
    switch (event['type']) {
      case 'message_start':
        _started = true;
        final message = (event['message'] as Map?)?.cast<String, Object?>();
        final id = message?['id'];
        if (id is String && id.isNotEmpty) _messageId = id;
        return [MessageStarted(messageId: _messageId, role: AiRole.assistant)];

      case 'content_block_start':
        final index = (event['index'] as num?)?.toInt() ?? 0;
        final block = (event['content_block'] as Map?)?.cast<String, Object?>();
        if (block?['type'] == 'tool_use') {
          final id = block?['id'] as String? ?? '$_messageId-tool-$index';
          final name = block?['name'] as String? ?? '';
          _toolCallIdByIndex[index] = id;
          return [
            ToolCallStarted(
              messageId: _messageId,
              toolCallId: id,
              toolName: name,
            ),
          ];
        }
        return const [];

      case 'content_block_delta':
        final index = (event['index'] as num?)?.toInt() ?? 0;
        final delta =
            (event['delta'] as Map?)?.cast<String, Object?>() ?? const {};
        switch (delta['type']) {
          case 'text_delta':
            final text = delta['text'] as String? ?? '';
            return text.isEmpty
                ? const []
                : [TextDelta(messageId: _messageId, delta: text)];
          case 'thinking_delta':
            final thinking = delta['thinking'] as String? ?? '';
            return thinking.isEmpty
                ? const []
                : [ReasoningDelta(messageId: _messageId, delta: thinking)];
          case 'input_json_delta':
            final id = _toolCallIdByIndex[index];
            final partial = delta['partial_json'] as String? ?? '';
            return (id == null || partial.isEmpty)
                ? const []
                : [ToolCallDelta(toolCallId: id, argumentsDelta: partial)];
        }
        return const [];

      case 'content_block_stop':
        final index = (event['index'] as num?)?.toInt() ?? 0;
        final id = _toolCallIdByIndex[index];
        return id == null ? const [] : [ToolCallReady(toolCallId: id)];

      case 'message_delta':
        final delta = (event['delta'] as Map?)?.cast<String, Object?>();
        final reason = delta?['stop_reason'];
        if (reason is String) _stopReason = reason;
        return const [];

      case 'message_stop':
        _finished = true;
        return [
          MessageFinished(
              messageId: _messageId, reason: _mapFinish(_stopReason)),
        ];

      case 'error':
        final error = (event['error'] as Map?)?.cast<String, Object?>();
        final message =
            error?['message'] as String? ?? 'Anthropic stream error';
        return [StreamErrorEvent(error: message, messageId: _messageId)];

      default:
        return const []; // ping and unknown events carry no state for us.
    }
  }

  static FinishReason _mapFinish(String reason) => switch (reason) {
        'end_turn' => FinishReason.stop,
        'stop_sequence' => FinishReason.stop,
        'max_tokens' => FinishReason.length,
        'tool_use' => FinishReason.toolCalls,
        'refusal' => FinishReason.contentFilter,
        _ => FinishReason.stop,
      };
}

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
  /// Creates a parser. When [structuredToolName] is set (structured output via a
  /// forced tool), that tool's streamed input is surfaced as [TextDelta]s — the
  /// JSON answer — rather than as a tool call.
  AnthropicEventParser({String? structuredToolName})
      : _structuredToolName = structuredToolName;

  final String? _structuredToolName;
  int? _structuredIndex;
  String _messageId = 'assistant';

  /// The id of the assistant message being built (for error finalization).
  String get messageId => _messageId;
  final Map<int, String> _toolCallIdByIndex = {};
  String _stopReason = 'end_turn';
  bool _started = false;
  bool _finished = false;
  int? _inputTokens;
  int? _cachedInputTokens;
  int? _outputTokens;

  /// Emits a terminal [MessageFinished] if the stream ended after starting but
  /// without a `message_stop` (e.g. a dropped connection), so the message isn't
  /// left streaming forever. Call once after the SSE stream completes.
  List<AiStreamEvent> finalize() => _started && !_finished
      ? [
          MessageFinished(
            messageId: _messageId,
            reason: _finishReason(),
            usage: _buildUsage(),
          ),
        ]
      : const [];

  AiUsage? _buildUsage() {
    if (_inputTokens == null && _outputTokens == null) return null;
    return AiUsage(
      inputTokens: _inputTokens,
      outputTokens: _outputTokens,
      cachedInputTokens: _cachedInputTokens,
    );
  }

  /// Returns the events implied by one decoded Anthropic stream event.
  List<AiStreamEvent> parse(Map<String, Object?> event) {
    switch (event['type']) {
      case 'message_start':
        _started = true;
        final message = (event['message'] as Map?)?.cast<String, Object?>();
        final id = message?['id'];
        if (id is String && id.isNotEmpty) _messageId = id;
        final usage = (message?['usage'] as Map?)?.cast<String, Object?>();
        if (usage != null) {
          final input = (usage['input_tokens'] as int?) ?? 0;
          final cacheRead = (usage['cache_read_input_tokens'] as int?) ?? 0;
          final cacheCreate =
              (usage['cache_creation_input_tokens'] as int?) ?? 0;
          _inputTokens = input + cacheRead + cacheCreate;
          _cachedInputTokens = cacheRead == 0 ? null : cacheRead;
          _outputTokens = usage['output_tokens'] as int?;
        }
        return [MessageStarted(messageId: _messageId, role: AiRole.assistant)];

      case 'content_block_start':
        final index = (event['index'] as num?)?.toInt() ?? 0;
        final block = (event['content_block'] as Map?)?.cast<String, Object?>();
        if (block?['type'] == 'tool_use') {
          final name = block?['name'] as String? ?? '';
          // Structured-output tool: capture its input as the JSON answer text
          // rather than exposing it as a tool call.
          if (_structuredToolName != null && name == _structuredToolName) {
            _structuredIndex = index;
            return const [];
          }
          final id = block?['id'] as String? ?? '$_messageId-tool-$index';
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
          case 'signature_delta':
            // The signed proof of the thinking block; must be replayed verbatim
            // on the next turn or the API rejects it.
            final sig = delta['signature'] as String? ?? '';
            return sig.isEmpty
                ? const []
                : [
                    ReasoningDelta(
                        messageId: _messageId, delta: '', signature: sig)
                  ];
          case 'input_json_delta':
            final partial = delta['partial_json'] as String? ?? '';
            if (index == _structuredIndex) {
              return partial.isEmpty
                  ? const []
                  : [TextDelta(messageId: _messageId, delta: partial)];
            }
            final id = _toolCallIdByIndex[index];
            return (id == null || partial.isEmpty)
                ? const []
                : [ToolCallDelta(toolCallId: id, argumentsDelta: partial)];
        }
        return const [];

      case 'content_block_stop':
        final index = (event['index'] as num?)?.toInt() ?? 0;
        if (index == _structuredIndex) return const [];
        final id = _toolCallIdByIndex[index];
        return id == null ? const [] : [ToolCallReady(toolCallId: id)];

      case 'message_delta':
        final delta = (event['delta'] as Map?)?.cast<String, Object?>();
        final reason = delta?['stop_reason'];
        if (reason is String) _stopReason = reason;
        final usage = (event['usage'] as Map?)?.cast<String, Object?>();
        final out = usage?['output_tokens'] as int?;
        if (out != null) _outputTokens = out;
        return const [];

      case 'message_stop':
        _finished = true;
        return [
          MessageFinished(
            messageId: _messageId,
            reason: _finishReason(),
            usage: _buildUsage(),
          ),
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

  // Structured output forces a tool call, so `tool_use` really means "done".
  FinishReason _finishReason() =>
      (_structuredIndex != null && _stopReason == 'tool_use')
          ? FinishReason.stop
          : _mapFinish(_stopReason);

  static FinishReason _mapFinish(String reason) => switch (reason) {
        'end_turn' => FinishReason.stop,
        'stop_sequence' => FinishReason.stop,
        'max_tokens' => FinishReason.length,
        'tool_use' => FinishReason.toolCalls,
        'refusal' => FinishReason.contentFilter,
        _ => FinishReason.stop,
      };
}

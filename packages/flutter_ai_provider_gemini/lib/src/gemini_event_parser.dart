import 'dart:convert';

import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Translates Google Gemini `streamGenerateContent` SSE chunks into
/// [AiStreamEvent]s.
///
/// Stateful across a single response: it emits a synthetic [MessageStarted] on
/// the first chunk (Gemini has no explicit start event), assigns ids to function
/// calls (Gemini delivers each call whole, not streamed), surfaces grounding
/// sources as [SourcePart]s, and maps the candidate's `finishReason`. Kept
/// separate from transport so it can be unit-tested against recorded chunks.
class GeminiEventParser {
  /// Creates a parser; [messageId] labels the assistant message it builds.
  GeminiEventParser({String messageId = 'assistant'}) : _messageId = messageId;

  final String _messageId;
  bool _started = false;
  int _toolSeq = 0;
  bool _sawToolCall = false;
  bool _finished = false;

  /// Emits a terminal [MessageFinished] if the stream ended after starting but
  /// without a `finishReason` (e.g. a dropped connection), so the message isn't
  /// left streaming forever. Call once after the SSE stream completes.
  List<AiStreamEvent> finalize() => _started && !_finished
      ? [
          MessageFinished(
            messageId: _messageId,
            reason: _sawToolCall ? FinishReason.toolCalls : FinishReason.stop,
          ),
        ]
      : const [];

  /// Returns the events implied by one decoded `GenerateContentResponse` chunk.
  List<AiStreamEvent> parse(Map<String, Object?> chunk) {
    final events = <AiStreamEvent>[];
    if (!_started) {
      _started = true;
      events.add(MessageStarted(messageId: _messageId, role: AiRole.assistant));
    }

    final candidates = chunk['candidates'];
    if (candidates is! List || candidates.isEmpty) return events;
    final candidate = (candidates.first as Map).cast<String, Object?>();

    final content = (candidate['content'] as Map?)?.cast<String, Object?>();
    final parts = content?['parts'];
    if (parts is List) {
      for (final raw in parts) {
        final part = (raw as Map).cast<String, Object?>();
        final text = part['text'];
        if (text is String && text.isNotEmpty) {
          // Gemini marks reasoning parts with `thought: true`.
          if (part['thought'] == true) {
            events.add(ReasoningDelta(messageId: _messageId, delta: text));
          } else {
            events.add(TextDelta(messageId: _messageId, delta: text));
          }
        }
        final functionCall = part['functionCall'];
        if (functionCall is Map) {
          final fn = functionCall.cast<String, Object?>();
          final name = fn['name'] as String? ?? '';
          final args =
              (fn['args'] as Map?)?.cast<String, Object?>() ?? const {};
          final id = '$_messageId-call-${_toolSeq++}';
          _sawToolCall = true;
          events.add(
            ToolCallStarted(
              messageId: _messageId,
              toolCallId: id,
              toolName: name,
            ),
          );
          events.add(
            ToolCallDelta(toolCallId: id, argumentsDelta: jsonEncode(args)),
          );
          events.add(ToolCallReady(toolCallId: id));
        }
      }
    }

    // Grounding sources (Google Search grounding) → SourcePart citations.
    final grounding =
        (candidate['groundingMetadata'] as Map?)?.cast<String, Object?>();
    final groundingChunks = grounding?['groundingChunks'];
    if (groundingChunks is List) {
      for (final raw in groundingChunks) {
        final web = ((raw as Map)['web'] as Map?)?.cast<String, Object?>();
        final uri = web?['uri'];
        if (uri is String && uri.isNotEmpty) {
          events.add(
            PartReceived(
              messageId: _messageId,
              part: SourcePart(
                url: Uri.parse(uri),
                title: web?['title'] as String?,
              ),
            ),
          );
        }
      }
    }

    final finishReason = candidate['finishReason'];
    if (finishReason is String) {
      _finished = true;
      events.add(
        MessageFinished(
          messageId: _messageId,
          reason:
              _sawToolCall ? FinishReason.toolCalls : _mapFinish(finishReason),
        ),
      );
    }

    return events;
  }

  static FinishReason _mapFinish(String reason) => switch (reason) {
        'STOP' => FinishReason.stop,
        'MAX_TOKENS' => FinishReason.length,
        'SAFETY' ||
        'RECITATION' ||
        'BLOCKLIST' ||
        'PROHIBITED_CONTENT' ||
        'SPII' =>
          FinishReason.contentFilter,
        _ => FinishReason.stop,
      };
}

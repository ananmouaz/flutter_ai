import 'package:flutter_ai_core/src/models/ai_conversation.dart';
import 'package:flutter_ai_core/src/models/ai_message.dart';
import 'package:flutter_ai_core/src/models/ai_part.dart';
import 'package:flutter_ai_core/src/models/ai_role.dart';
import 'package:flutter_ai_core/src/models/finish_reason.dart';
import 'package:flutter_ai_core/src/models/tool_call_state.dart';
import 'package:flutter_ai_core/src/streaming/ai_stream_event.dart';
import 'package:flutter_ai_core/src/streaming/json_accumulator.dart';
import 'package:flutter_ai_core/src/streaming/mutation_result.dart';

/// Folds a stream of [AiStreamEvent]s into evolving [AiConversation] state.
///
/// The processor is a pure, synchronous, Flutter-free reducer: each [apply]
/// call returns the new conversation plus the ids of the messages that changed,
/// so a host can rebuild only those nodes. It does **no** scheduling itself —
/// batching updates to the frame boundary is the consumer's job, which keeps the
/// reducer testable and the package UI-agnostic.
///
/// Tool-call arguments are accumulated per call and parsed tolerantly while
/// streaming (see [JsonAccumulator]); a [ToolCallReady] event triggers a strict
/// re-parse. Malformed arguments do not throw — the offending call is marked
/// [ToolCallState.error] and an error [ToolResultPart] is appended, so the rest
/// of the stream proceeds unaffected.
class MessageProcessor {
  /// Creates a processor seeded with an optional starting [conversation].
  MessageProcessor({AiConversation? conversation})
      : _conversation = conversation ?? const AiConversation.empty('default');

  AiConversation _conversation;
  final Map<String, JsonAccumulator> _argAccumulators = {};
  final Map<String, String> _toolCallToMessage = {};

  /// The current conversation state.
  AiConversation get conversation => _conversation;

  /// Resets the processor to [conversation], discarding streaming scratch state.
  void reset(AiConversation conversation) {
    _conversation = conversation;
    _argAccumulators.clear();
    _toolCallToMessage.clear();
  }

  /// Applies [event] and returns the resulting [MutationResult].
  MutationResult apply(AiStreamEvent event) {
    switch (event) {
      case MessageStarted(:final messageId, :final role):
        if (_conversation.messageById(messageId) == null) {
          _conversation = _conversation.append(
            AiMessage(
              id: messageId,
              role: role,
              status: AiMessageStatus.streaming,
            ),
          );
        }
        return _changed(messageId);

      case TextDelta(:final messageId, :final delta):
        _mutate(messageId, (m) => _appendText(m, delta));
        return _changed(messageId);

      case ReasoningDelta(:final messageId, :final delta, :final signature):
        _mutate(messageId, (m) => _appendReasoning(m, delta, signature));
        return _changed(messageId);

      case ToolCallStarted(
          :final messageId,
          :final toolCallId,
          :final toolName
        ):
        _toolCallToMessage[toolCallId] = messageId;
        _argAccumulators[toolCallId] = JsonAccumulator();
        _mutate(
          messageId,
          (m) => m.copyWith(
            parts: [
              ...m.parts,
              ToolCallPart(toolCallId: toolCallId, toolName: toolName),
            ],
            status: AiMessageStatus.streaming,
          ),
        );
        return _changed(messageId);

      case ToolCallDelta(:final toolCallId, :final argumentsDelta):
        final messageId = _toolCallToMessage[toolCallId];
        final accumulator = _argAccumulators[toolCallId];
        if (messageId == null || accumulator == null) return _none();
        accumulator.add(argumentsDelta);
        final partial = accumulator.parsePartial();
        _updateToolCall(
          messageId,
          toolCallId,
          (p) => p.copyWith(
            // Keep the last good partial args when this fragment isn't yet
            // parseable, rather than clobbering to {} and flickering the UI.
            args: partial is Map ? partial.cast<String, Object?>() : p.args,
            state: ToolCallState.inputStreaming,
          ),
        );
        return _changed(messageId);

      case ToolCallReady(:final toolCallId):
        final messageId = _toolCallToMessage[toolCallId];
        final accumulator = _argAccumulators[toolCallId];
        if (messageId == null || accumulator == null) return _none();
        final parsed = accumulator.tryParseComplete();
        if (parsed is Map) {
          _updateToolCall(
            messageId,
            toolCallId,
            (p) => p.copyWith(
              args: parsed.cast<String, Object?>(),
              state: ToolCallState.inputAvailable,
            ),
          );
        } else if (accumulator.raw.trim().isEmpty) {
          // No arguments were streamed — a legitimate zero-argument tool call
          // (e.g. `get_current_time`). Treat as empty args, not an error.
          _updateToolCall(
            messageId,
            toolCallId,
            (p) => p.copyWith(
              args: const {},
              state: ToolCallState.inputAvailable,
            ),
          );
        } else {
          // Malformed arguments: halt this call without crashing the stream.
          _updateToolCall(
            messageId,
            toolCallId,
            (p) => p.copyWith(state: ToolCallState.error),
          );
          _mutate(
            messageId,
            (m) => m.copyWith(
              parts: [
                ...m.parts,
                ToolResultPart(
                  toolCallId: toolCallId,
                  result: 'Invalid tool arguments: ${accumulator.raw}',
                  isError: true,
                ),
              ],
            ),
          );
        }
        return _changed(messageId);

      case ToolResultReceived(
          :final messageId,
          :final toolCallId,
          :final result,
          :final isError,
        ):
        // The call lives in the assistant message it was started on, which is
        // usually *not* the message carrying the result (e.g. a separate
        // tool-role message). Advance the call's state in its owning message.
        // After a reset()/rehydration the in-memory map is empty, so fall back
        // to scanning the conversation for the message that actually holds the
        // matching ToolCallPart before using the result's own message id.
        _updateToolCall(
          _toolCallToMessage[toolCallId] ??
              _messageIdForToolCall(toolCallId) ??
              messageId,
          toolCallId,
          (p) => p.copyWith(
            state:
                isError ? ToolCallState.error : ToolCallState.outputAvailable,
          ),
        );
        _mutate(
          messageId,
          (m) => m.copyWith(
            parts: [
              ...m.parts,
              ToolResultPart(
                toolCallId: toolCallId,
                result: result,
                isError: isError,
              ),
            ],
          ),
        );
        return _changed(messageId);

      case PartReceived(:final messageId, :final part):
        _mutate(
          messageId,
          (m) => m.copyWith(
            parts: [...m.parts, part],
            status: AiMessageStatus.streaming,
          ),
        );
        return _changed(messageId);

      case MessageFinished(:final messageId, :final reason, :final usage):
        _mutate(
          messageId,
          (m) => m.copyWith(
            // Freeze any streaming buffer into a plain, detached part so the
            // settled transcript message never pins a live StringBuffer.
            parts: _freezeBuffers(m.parts),
            status: reason == FinishReason.error
                ? AiMessageStatus.error
                : AiMessageStatus.complete,
            finishReason: reason,
            usage: usage,
          ),
        );
        return _changed(messageId);

      case StreamErrorEvent(:final messageId, :final toolCallId):
        // A tool-scoped error fails only that call; generation continues, so
        // don't mark the whole message errored (matches UseChatController).
        if (toolCallId != null) {
          final callMessageId = _toolCallToMessage[toolCallId];
          if (callMessageId == null) return _none();
          _updateToolCall(
            callMessageId,
            toolCallId,
            (p) => p.copyWith(state: ToolCallState.error),
          );
          return _changed(callMessageId);
        }
        if (messageId == null) return _none();
        _mutate(
          messageId,
          (m) => m.copyWith(
            status: AiMessageStatus.error,
            finishReason: FinishReason.error,
          ),
        );
        return _changed(messageId);
    }
  }

  /// Ensures a message with [messageId] exists, applies [transform], and stores
  /// the result. A missing message is created as a streaming [roleIfAbsent]
  /// message, so a content event that arrives without a [MessageStarted] still
  /// works.
  void _mutate(
    String messageId,
    AiMessage Function(AiMessage message) transform, {
    AiRole roleIfAbsent = AiRole.assistant,
  }) {
    final existing = _conversation.messageById(messageId) ??
        AiMessage(
          id: messageId,
          role: roleIfAbsent,
          status: AiMessageStatus.streaming,
        );
    _conversation = _conversation.replace(transform(existing));
  }

  /// Finds the id of the message whose parts contain a [ToolCallPart] with
  /// [toolCallId], or `null` if no such message exists. Used to recover the
  /// call→message mapping that lives only in memory when results arrive after a
  /// [reset] or against a seeded conversation.
  String? _messageIdForToolCall(String toolCallId) {
    for (final message in _conversation.messages) {
      for (final part in message.parts) {
        if (part is ToolCallPart && part.toolCallId == toolCallId) {
          return message.id;
        }
      }
    }
    return null;
  }

  void _updateToolCall(
    String messageId,
    String toolCallId,
    ToolCallPart Function(ToolCallPart part) transform,
  ) {
    _mutate(messageId, (m) {
      final parts = [...m.parts];
      final index = parts.indexWhere(
        (p) => p is ToolCallPart && p.toolCallId == toolCallId,
      );
      if (index == -1) return m;
      parts[index] = transform(parts[index] as ToolCallPart);
      return m.copyWith(parts: parts);
    });
  }

  // Text and reasoning deltas accumulate into a per-part [StringBuffer] rather
  // than `last.text + delta`, which would reallocate the whole accumulated
  // string on every token (quadratic on long answers). The buffer is appended
  // to in place — O(delta) — and the resulting String is materialized lazily,
  // only when a consumer reads `TextPart.text`/`ReasoningPart.text`. A buffered
  // part already at the tail carries its buffer, so we keep writing to it; a
  // plain part (e.g. rehydrated from a stored String) seeds a fresh buffer with
  // its current text on the first delta. A non-text part at the tail forces a
  // new buffer, so buffers never merge across a part boundary.

  AiMessage _appendText(AiMessage message, String delta) {
    final parts = [...message.parts];
    final last = parts.isEmpty ? null : parts.last;
    if (last is TextPart) {
      final buffer = last.buffer ?? (StringBuffer()..write(last.text));
      buffer.write(delta);
      parts[parts.length - 1] = TextPart.buffered(buffer);
    } else {
      parts.add(TextPart.buffered(StringBuffer()..write(delta)));
    }
    return message.copyWith(parts: parts, status: AiMessageStatus.streaming);
  }

  AiMessage _appendReasoning(AiMessage message, String delta, [String? sig]) {
    final parts = [...message.parts];
    final last = parts.isEmpty ? null : parts.last;
    if (last is ReasoningPart) {
      final buffer = last.buffer ?? (StringBuffer()..write(last.text));
      buffer.write(delta);
      parts[parts.length - 1] = ReasoningPart.buffered(
        buffer,
        signature: sig ?? last.signature,
      );
    } else {
      parts.add(
          ReasoningPart.buffered(StringBuffer()..write(delta), signature: sig));
    }
    return message.copyWith(parts: parts, status: AiMessageStatus.streaming);
  }

  /// Materializes any still-buffered [TextPart]/[ReasoningPart] into plain,
  /// detached parts. Called when a message settles so the stored transcript
  /// holds ordinary value objects rather than references to a live buffer.
  List<AiPart> _freezeBuffers(List<AiPart> parts) {
    var changed = false;
    final frozen = <AiPart>[];
    for (final part in parts) {
      if (part is TextPart && part.buffer != null) {
        frozen.add(TextPart(part.text));
        changed = true;
      } else if (part is ReasoningPart && part.buffer != null) {
        frozen.add(ReasoningPart(part.text, signature: part.signature));
        changed = true;
      } else {
        frozen.add(part);
      }
    }
    return changed ? frozen : parts;
  }

  MutationResult _changed(String messageId) => MutationResult(
        conversation: _conversation,
        changedMessageIds: {messageId},
      );

  MutationResult _none() => MutationResult(
        conversation: _conversation,
        changedMessageIds: const {},
      );
}

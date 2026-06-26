import 'package:flutter_ai_core/src/models/ai_conversation.dart';

/// The outcome of applying one stream event to a `MessageProcessor`.
///
/// Carries the updated [conversation] and the set of message ids that changed.
/// A UI binds the latter to rebuild only the affected messages — never the whole
/// transcript — which is what keeps streaming at frame rate.
final class MutationResult {
  /// Creates a mutation result.
  const MutationResult({
    required this.conversation,
    required this.changedMessageIds,
  });

  /// The conversation after the event was applied.
  final AiConversation conversation;

  /// The ids of messages whose content changed. Empty when the event was a
  /// no-op (for example, an event referencing an unknown id).
  final Set<String> changedMessageIds;

  /// Whether the event changed any message.
  bool get hasChanges => changedMessageIds.isNotEmpty;

  @override
  String toString() => 'MutationResult(changed: $changedMessageIds, '
      'messages: ${conversation.messages.length})';
}

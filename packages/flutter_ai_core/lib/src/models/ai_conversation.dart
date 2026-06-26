import 'package:flutter_ai_core/src/internal/equality.dart';
import 'package:flutter_ai_core/src/models/ai_message.dart';

/// An ordered, immutable transcript of [AiMessage]s.
///
/// The conversation retains the **full** message history; trimming for token
/// budgets is deliberately out of scope and belongs to the server or provider
/// integration, so the user can always scroll back through the entire session.
///
/// Every mutating helper returns a new instance, preserving value semantics.
final class AiConversation {
  /// Creates a conversation.
  const AiConversation({required this.id, this.messages = const []});

  /// An empty conversation with the given [id].
  const AiConversation.empty(String id) : this(id: id);

  /// Reconstructs a conversation from [json].
  factory AiConversation.fromJson(Map<String, Object?> json) {
    final rawMessages = (json['messages'] as List?) ?? const [];
    return AiConversation(
      id: json['id']! as String,
      messages: [
        for (final message in rawMessages)
          AiMessage.fromJson((message! as Map).cast<String, Object?>()),
      ],
    );
  }

  /// A stable, unique identifier for this conversation.
  final String id;

  /// The full ordered transcript.
  final List<AiMessage> messages;

  /// The most recent message, or `null` if the conversation is empty.
  AiMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  /// Returns the message with the given [messageId], or `null` if absent.
  AiMessage? messageById(String messageId) {
    for (final message in messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  /// Returns a copy with [message] appended.
  AiConversation append(AiMessage message) =>
      copyWith(messages: [...messages, message]);

  /// Returns a copy in which the message sharing [message]'s id is replaced.
  ///
  /// If no message has that id, [message] is appended instead, making this safe
  /// to call as an upsert during streaming.
  AiConversation replace(AiMessage message) {
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return append(message);
    final next = [...messages]..[index] = message;
    return copyWith(messages: next);
  }

  /// Returns a copy with the given fields replaced.
  AiConversation copyWith({String? id, List<AiMessage>? messages}) =>
      AiConversation(id: id ?? this.id, messages: messages ?? this.messages);

  /// Serializes this conversation.
  Map<String, Object?> toJson() => {
        'id': id,
        'messages': [for (final message in messages) message.toJson()],
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConversation &&
          other.id == id &&
          deepEquals(other.messages, messages));

  @override
  int get hashCode => Object.hash(id, Object.hashAll(messages));

  @override
  String toString() => 'AiConversation(id: $id, messages: ${messages.length})';
}

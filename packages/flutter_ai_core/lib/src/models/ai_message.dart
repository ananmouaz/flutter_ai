import 'package:flutter_ai_core/src/internal/equality.dart';
import 'package:flutter_ai_core/src/models/ai_part.dart';
import 'package:flutter_ai_core/src/models/ai_role.dart';
import 'package:flutter_ai_core/src/models/finish_reason.dart';

/// The delivery state of an [AiMessage].
enum AiMessageStatus {
  /// Created locally and awaiting a response; no content yet.
  pending('pending'),

  /// Content is actively streaming in.
  streaming('streaming'),

  /// Fully received.
  complete('complete'),

  /// Terminated by an error.
  error('error');

  const AiMessageStatus(this.wireName);

  /// The stable string used on the wire and in JSON.
  final String wireName;

  /// Parses a [wireName] into its [AiMessageStatus].
  ///
  /// Throws a [FormatException] if [value] is not a known status.
  static AiMessageStatus fromJson(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    throw FormatException('Unknown AiMessageStatus: "$value"');
  }

  /// The wire representation of this status.
  String toJson() => wireName;
}

/// A single turn in a conversation, authored by one [AiRole].
///
/// A message is an ordered, immutable list of [parts]; mutations during
/// streaming produce new [AiMessage] instances via [copyWith] rather than
/// editing in place, preserving value semantics.
final class AiMessage {
  /// Creates a message.
  const AiMessage({
    required this.id,
    required this.role,
    this.parts = const [],
    this.status = AiMessageStatus.complete,
    this.finishReason,
    this.createdAt,
  });

  /// Convenience constructor for a plain-text message.
  AiMessage.text({
    required String id,
    required AiRole role,
    required String text,
    AiMessageStatus status = AiMessageStatus.complete,
    DateTime? createdAt,
  }) : this(
          id: id,
          role: role,
          parts: [TextPart(text)],
          status: status,
          createdAt: createdAt,
        );

  /// Reconstructs a message from [json].
  factory AiMessage.fromJson(Map<String, Object?> json) {
    final rawParts = (json['parts'] as List?) ?? const [];
    final createdAt = json['createdAt'] as String?;
    final finishReason = json['finishReason'] as String?;
    return AiMessage(
      id: json['id']! as String,
      role: AiRole.fromJson(json['role']! as String),
      parts: [
        for (final part in rawParts)
          AiPart.fromJson((part! as Map).cast<String, Object?>()),
      ],
      status: AiMessageStatus.fromJson(json['status']! as String),
      finishReason:
          finishReason == null ? null : FinishReason.fromJson(finishReason),
      createdAt: createdAt == null ? null : DateTime.parse(createdAt),
    );
  }

  /// A stable, unique identifier for this message.
  final String id;

  /// Who authored the message.
  final AiRole role;

  /// The ordered content of the message.
  final List<AiPart> parts;

  /// The current delivery state.
  final AiMessageStatus status;

  /// Why generation stopped, once [status] is terminal. `null` while pending or
  /// streaming.
  final FinishReason? finishReason;

  /// When the message was created, if tracked.
  final DateTime? createdAt;

  /// The concatenated text of every [TextPart], ignoring other part types.
  ///
  /// A convenience for the common case of reading a message's prose.
  String get text => parts.whereType<TextPart>().map((p) => p.text).join();

  /// Returns a copy with the given fields replaced.
  ///
  /// Passing [finishReason] or [createdAt] cannot clear them to `null`; that is
  /// an intentional trade-off favoring the common "set or keep" case.
  AiMessage copyWith({
    String? id,
    AiRole? role,
    List<AiPart>? parts,
    AiMessageStatus? status,
    FinishReason? finishReason,
    DateTime? createdAt,
  }) =>
      AiMessage(
        id: id ?? this.id,
        role: role ?? this.role,
        parts: parts ?? this.parts,
        status: status ?? this.status,
        finishReason: finishReason ?? this.finishReason,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Serializes this message.
  Map<String, Object?> toJson() => {
        'id': id,
        'role': role.toJson(),
        'parts': [for (final part in parts) part.toJson()],
        'status': status.toJson(),
        if (finishReason != null) 'finishReason': finishReason!.toJson(),
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiMessage &&
          other.id == id &&
          other.role == role &&
          other.status == status &&
          other.finishReason == finishReason &&
          other.createdAt == createdAt &&
          deepEquals(other.parts, parts));

  @override
  int get hashCode => Object.hash(
        id,
        role,
        status,
        finishReason,
        createdAt,
        Object.hashAll(parts),
      );

  @override
  String toString() =>
      'AiMessage(id: $id, role: ${role.name}, status: ${status.name}, '
      'parts: ${parts.length})';
}

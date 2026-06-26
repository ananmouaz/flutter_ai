import 'package:flutter_ai_core/src/internal/equality.dart';
import 'package:flutter_ai_core/src/models/ai_part.dart';
import 'package:flutter_ai_core/src/models/ai_role.dart';
import 'package:flutter_ai_core/src/models/finish_reason.dart';

/// A single incremental update emitted by an `LlmProvider` during generation.
///
/// Providers translate their native protocol (SSE, gRPC, a local callback) into
/// this sealed set of events; a `MessageProcessor` folds them into conversation
/// state. Because the type is `sealed`, a `switch` over an event is exhaustively
/// checked, and adding an event forces every consumer to handle it.
///
/// Events round-trip through JSON so a generic transport can serialize them and
/// tests can replay recorded streams. [AiStreamEvent.fromJson] dispatches on the
/// `type` discriminator.
sealed class AiStreamEvent {
  /// Const base constructor for subclasses.
  const AiStreamEvent();

  /// Reconstructs an event from [json] by dispatching on `type`.
  ///
  /// Throws a [FormatException] if `type` is missing or unrecognized.
  factory AiStreamEvent.fromJson(Map<String, Object?> json) {
    final type = json['type'];
    return switch (type) {
      'message-started' => MessageStarted.fromJson(json),
      'text-delta' => TextDelta.fromJson(json),
      'reasoning-delta' => ReasoningDelta.fromJson(json),
      'tool-call-started' => ToolCallStarted.fromJson(json),
      'tool-call-delta' => ToolCallDelta.fromJson(json),
      'tool-call-ready' => ToolCallReady.fromJson(json),
      'tool-result' => ToolResultReceived.fromJson(json),
      'part-received' => PartReceived.fromJson(json),
      'message-finished' => MessageFinished.fromJson(json),
      'error' => StreamErrorEvent.fromJson(json),
      _ => throw FormatException('Unknown AiStreamEvent type: "$type"'),
    };
  }

  /// Serializes this event, including its `type` discriminator.
  Map<String, Object?> toJson();
}

/// Announces a new message and its author, before any content arrives.
///
/// Optional: a processor will lazily create an assistant message on the first
/// content event if no start was sent.
final class MessageStarted extends AiStreamEvent {
  /// Creates a message-started event.
  const MessageStarted({required this.messageId, required this.role});

  /// Reconstructs a [MessageStarted] from [json].
  factory MessageStarted.fromJson(Map<String, Object?> json) => MessageStarted(
        messageId: json['messageId']! as String,
        role: AiRole.fromJson(json['role']! as String),
      );

  /// The id of the message being started.
  final String messageId;

  /// Who authors the message.
  final AiRole role;

  @override
  Map<String, Object?> toJson() => {
        'type': 'message-started',
        'messageId': messageId,
        'role': role.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageStarted &&
          other.messageId == messageId &&
          other.role == role);

  @override
  int get hashCode => Object.hash(messageId, role);

  @override
  String toString() => 'MessageStarted($messageId, ${role.name})';
}

/// Appends [delta] to the prose of message [messageId].
final class TextDelta extends AiStreamEvent {
  /// Creates a text-delta event.
  const TextDelta({required this.messageId, required this.delta});

  /// Reconstructs a [TextDelta] from [json].
  factory TextDelta.fromJson(Map<String, Object?> json) => TextDelta(
        messageId: json['messageId']! as String,
        delta: json['delta']! as String,
      );

  /// The message receiving the text.
  final String messageId;

  /// The text fragment to append.
  final String delta;

  @override
  Map<String, Object?> toJson() =>
      {'type': 'text-delta', 'messageId': messageId, 'delta': delta};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TextDelta &&
          other.messageId == messageId &&
          other.delta == delta);

  @override
  int get hashCode => Object.hash(messageId, delta);

  @override
  String toString() => 'TextDelta($messageId, ${delta.length} chars)';
}

/// Appends [delta] to the reasoning of message [messageId].
final class ReasoningDelta extends AiStreamEvent {
  /// Creates a reasoning-delta event.
  const ReasoningDelta({required this.messageId, required this.delta});

  /// Reconstructs a [ReasoningDelta] from [json].
  factory ReasoningDelta.fromJson(Map<String, Object?> json) => ReasoningDelta(
        messageId: json['messageId']! as String,
        delta: json['delta']! as String,
      );

  /// The message receiving the reasoning.
  final String messageId;

  /// The reasoning fragment to append.
  final String delta;

  @override
  Map<String, Object?> toJson() =>
      {'type': 'reasoning-delta', 'messageId': messageId, 'delta': delta};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReasoningDelta &&
          other.messageId == messageId &&
          other.delta == delta);

  @override
  int get hashCode => Object.hash(messageId, delta);

  @override
  String toString() => 'ReasoningDelta($messageId, ${delta.length} chars)';
}

/// Opens a tool call within message [messageId].
///
/// Followed by zero or more [ToolCallDelta]s carrying the argument JSON, then a
/// [ToolCallReady] once the arguments are complete.
final class ToolCallStarted extends AiStreamEvent {
  /// Creates a tool-call-started event.
  const ToolCallStarted({
    required this.messageId,
    required this.toolCallId,
    required this.toolName,
  });

  /// Reconstructs a [ToolCallStarted] from [json].
  factory ToolCallStarted.fromJson(Map<String, Object?> json) =>
      ToolCallStarted(
        messageId: json['messageId']! as String,
        toolCallId: json['toolCallId']! as String,
        toolName: json['toolName']! as String,
      );

  /// The message the call belongs to.
  final String messageId;

  /// The id correlating this call with its result.
  final String toolCallId;

  /// The name of the tool being invoked.
  final String toolName;

  @override
  Map<String, Object?> toJson() => {
        'type': 'tool-call-started',
        'messageId': messageId,
        'toolCallId': toolCallId,
        'toolName': toolName,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolCallStarted &&
          other.messageId == messageId &&
          other.toolCallId == toolCallId &&
          other.toolName == toolName);

  @override
  int get hashCode => Object.hash(messageId, toolCallId, toolName);

  @override
  String toString() => 'ToolCallStarted($toolName, id: $toolCallId)';
}

/// Appends a fragment of argument JSON to tool call [toolCallId].
///
/// The fragments accumulate; the JSON is partial until [ToolCallReady].
final class ToolCallDelta extends AiStreamEvent {
  /// Creates a tool-call-delta event.
  const ToolCallDelta({
    required this.toolCallId,
    required this.argumentsDelta,
  });

  /// Reconstructs a [ToolCallDelta] from [json].
  factory ToolCallDelta.fromJson(Map<String, Object?> json) => ToolCallDelta(
        toolCallId: json['toolCallId']! as String,
        argumentsDelta: json['argumentsDelta']! as String,
      );

  /// The call whose arguments are growing.
  final String toolCallId;

  /// A fragment of the arguments JSON.
  final String argumentsDelta;

  @override
  Map<String, Object?> toJson() => {
        'type': 'tool-call-delta',
        'toolCallId': toolCallId,
        'argumentsDelta': argumentsDelta,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolCallDelta &&
          other.toolCallId == toolCallId &&
          other.argumentsDelta == argumentsDelta);

  @override
  int get hashCode => Object.hash(toolCallId, argumentsDelta);

  @override
  String toString() =>
      'ToolCallDelta($toolCallId, ${argumentsDelta.length} chars)';
}

/// Signals that tool call [toolCallId] has received all its arguments.
///
/// The processor strictly parses the accumulated JSON: on success the call
/// advances to `ToolCallState.inputAvailable`; on failure it is marked errored.
final class ToolCallReady extends AiStreamEvent {
  /// Creates a tool-call-ready event.
  const ToolCallReady({required this.toolCallId});

  /// Reconstructs a [ToolCallReady] from [json].
  factory ToolCallReady.fromJson(Map<String, Object?> json) =>
      ToolCallReady(toolCallId: json['toolCallId']! as String);

  /// The call whose arguments are now complete.
  final String toolCallId;

  @override
  Map<String, Object?> toJson() =>
      {'type': 'tool-call-ready', 'toolCallId': toolCallId};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolCallReady && other.toolCallId == toolCallId);

  @override
  int get hashCode => toolCallId.hashCode;

  @override
  String toString() => 'ToolCallReady($toolCallId)';
}

/// Delivers the output of tool call [toolCallId] into message [messageId].
final class ToolResultReceived extends AiStreamEvent {
  /// Creates a tool-result event.
  const ToolResultReceived({
    required this.messageId,
    required this.toolCallId,
    required this.result,
    this.isError = false,
  });

  /// Reconstructs a [ToolResultReceived] from [json].
  factory ToolResultReceived.fromJson(Map<String, Object?> json) =>
      ToolResultReceived(
        messageId: json['messageId']! as String,
        toolCallId: json['toolCallId']! as String,
        result: json['result'],
        isError: json['isError'] as bool? ?? false,
      );

  /// The message the result attaches to.
  final String messageId;

  /// The call this result answers.
  final String toolCallId;

  /// The tool's output (any JSON-encodable value, or `null`).
  final Object? result;

  /// Whether [result] is an error payload.
  final bool isError;

  @override
  Map<String, Object?> toJson() => {
        'type': 'tool-result',
        'messageId': messageId,
        'toolCallId': toolCallId,
        'result': result,
        'isError': isError,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolResultReceived &&
          other.messageId == messageId &&
          other.toolCallId == toolCallId &&
          other.isError == isError &&
          deepEquals(other.result, result));

  @override
  int get hashCode =>
      Object.hash(messageId, toolCallId, isError, deepHash(result));

  @override
  String toString() => 'ToolResultReceived($toolCallId, isError: $isError)';
}

/// Appends a fully-formed [part] (a file, source, or data payload) to message
/// [messageId].
final class PartReceived extends AiStreamEvent {
  /// Creates a part-received event.
  const PartReceived({required this.messageId, required this.part});

  /// Reconstructs a [PartReceived] from [json].
  factory PartReceived.fromJson(Map<String, Object?> json) => PartReceived(
        messageId: json['messageId']! as String,
        part: AiPart.fromJson((json['part']! as Map).cast<String, Object?>()),
      );

  /// The message receiving the part.
  final String messageId;

  /// The complete part to append.
  final AiPart part;

  @override
  Map<String, Object?> toJson() =>
      {'type': 'part-received', 'messageId': messageId, 'part': part.toJson()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartReceived &&
          other.messageId == messageId &&
          other.part == part);

  @override
  int get hashCode => Object.hash(messageId, part);

  @override
  String toString() => 'PartReceived($messageId, $part)';
}

/// Marks message [messageId] complete, carrying the [reason] generation ended.
final class MessageFinished extends AiStreamEvent {
  /// Creates a message-finished event.
  const MessageFinished({required this.messageId, required this.reason});

  /// Reconstructs a [MessageFinished] from [json].
  factory MessageFinished.fromJson(Map<String, Object?> json) =>
      MessageFinished(
        messageId: json['messageId']! as String,
        reason: FinishReason.fromJson(json['reason']! as String),
      );

  /// The message that finished.
  final String messageId;

  /// Why generation stopped.
  final FinishReason reason;

  @override
  Map<String, Object?> toJson() => {
        'type': 'message-finished',
        'messageId': messageId,
        'reason': reason.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageFinished &&
          other.messageId == messageId &&
          other.reason == reason);

  @override
  int get hashCode => Object.hash(messageId, reason);

  @override
  String toString() => 'MessageFinished($messageId, ${reason.name})';
}

/// Reports an error during generation.
///
/// When [messageId] is set, the processor marks that message errored; a scoped
/// [toolCallId] additionally flags the offending tool call. A `null`
/// [messageId] denotes a stream-level failure not tied to one message.
final class StreamErrorEvent extends AiStreamEvent {
  /// Creates an error event.
  const StreamErrorEvent({
    required this.error,
    this.messageId,
    this.toolCallId,
  });

  /// Reconstructs a [StreamErrorEvent] from [json].
  ///
  /// The original error object is not recoverable from JSON; its string form is
  /// restored as the [error].
  factory StreamErrorEvent.fromJson(Map<String, Object?> json) =>
      StreamErrorEvent(
        error: json['error']! as String,
        messageId: json['messageId'] as String?,
        toolCallId: json['toolCallId'] as String?,
      );

  /// The error that occurred.
  final Object error;

  /// The affected message, if the failure is scoped to one.
  final String? messageId;

  /// The affected tool call, if the failure is scoped to one.
  final String? toolCallId;

  @override
  Map<String, Object?> toJson() => {
        'type': 'error',
        'error': error.toString(),
        if (messageId != null) 'messageId': messageId,
        if (toolCallId != null) 'toolCallId': toolCallId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreamErrorEvent &&
          other.error.toString() == error.toString() &&
          other.messageId == messageId &&
          other.toolCallId == toolCallId);

  @override
  int get hashCode => Object.hash(error.toString(), messageId, toolCallId);

  @override
  String toString() => 'StreamErrorEvent($error, messageId: $messageId)';
}

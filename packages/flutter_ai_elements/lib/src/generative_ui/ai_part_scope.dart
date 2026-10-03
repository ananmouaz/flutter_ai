import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';

/// The position of a part in a displayed message snapshot.
///
/// Indices remain valid while parts are appended. Do not reuse a reference
/// after replacing or reordering that message's parts; hosts must validate
/// delayed actions against their current conversation before applying them.
@immutable
class AiPartRef {
  /// Addresses the original [partIndex] in [messageId], including hidden parts.
  const AiPartRef({required this.messageId, required this.partIndex})
      : assert(partIndex >= 0);

  /// The containing message's id.
  final String messageId;

  /// The zero-based index in the message's parts, not its rendered children.
  final int partIndex;

  @override
  bool operator ==(Object other) =>
      other is AiPartRef &&
      other.messageId == messageId &&
      other.partIndex == partIndex;

  @override
  int get hashCode => Object.hash(messageId, partIndex);
}

/// Reports a part action to its host without mutating the conversation.
///
/// An asynchronous handler can be awaited by a question or another control.
typedef AiPartActionCallback = FutureOr<void> Function(
  AiPartRef ref,
  Object? value,
);

/// Overrides one part. Return null to use its registry or default renderer.
///
/// [context] inherits the bubble's text style and [AiPartScope]. A whole-message
/// builder takes precedence over this hook and owns any forwarding itself.
typedef AiPartBuilder = Widget? Function(
  BuildContext context,
  AiPart part,
  AiMessage message,
);

/// Supplies part identity and an optional action channel to custom widgets.
///
/// Both registry builders and [AiPartBuilder] can read [maybeOf]. Bind controls
/// to [onAction]; it is null without a host handler or while the message streams.
/// The scope never submits messages, executes tools, or changes the transcript.
class AiPartScope extends InheritedWidget {
  /// Provides an addressed action channel to [child].
  const AiPartScope({
    super.key,
    required this.ref,
    required this.onAction,
    required super.child,
  });

  /// The original position of this part in the displayed message.
  final AiPartRef ref;

  /// Sends a value to the host; null means controls using this channel are inert.
  final FutureOr<void> Function(Object? value)? onAction;

  /// Returns the enclosing part scope, or null outside a transcript part.
  static AiPartScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AiPartScope>();

  @override
  bool updateShouldNotify(AiPartScope oldWidget) =>
      ref != oldWidget.ref || onAction != oldWidget.onAction;
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';

/// The per-message actions, used to control ordering via
/// [AiMessageActions.order] and [AiMessageActions.trailing].
enum AiMessageActionKind {
  /// Copy the message text.
  copy,

  /// Read the message aloud.
  speak,

  /// Thumbs-up feedback.
  good,

  /// Thumbs-down feedback.
  bad,

  /// Share the message.
  share,

  /// Regenerate the response.
  regenerate,

  /// Edit the message.
  edit,
}

/// A compact row of per-message actions: copy, and optionally regenerate and
/// edit.
///
/// Copy defaults to placing the message's text on the clipboard; override it via
/// [onCopy]. On mobile, prefer presenting these via [showAiMessageActions] from
/// a long-press rather than always-visible buttons.
///
/// [order] controls the sequence; actions listed in [trailing] are pushed to the
/// far (end) side after a spacer — e.g. Gemini keeps 👍👎↻⧉⋮ on the left and
/// read-aloud on the right. Only actions with a non-null callback render (copy
/// always renders).
class AiMessageActions extends StatelessWidget {
  /// Creates an actions row for [message].
  const AiMessageActions({
    super.key,
    required this.message,
    this.onCopy,
    this.onSpeak,
    this.onGood,
    this.onBad,
    this.onShare,
    this.onRegenerate,
    this.onEdit,
    this.iconSize = 18,
    this.order = const [
      AiMessageActionKind.copy,
      AiMessageActionKind.speak,
      AiMessageActionKind.good,
      AiMessageActionKind.bad,
      AiMessageActionKind.share,
      AiMessageActionKind.regenerate,
      AiMessageActionKind.edit,
    ],
    this.trailing = const {},
  });

  /// The message these actions apply to.
  final AiMessage message;

  /// Overrides the default copy-to-clipboard behavior.
  final VoidCallback? onCopy;

  /// Shows a read-aloud action when non-null.
  final VoidCallback? onSpeak;

  /// Shows a thumbs-up action when non-null.
  final VoidCallback? onGood;

  /// Shows a thumbs-down action when non-null.
  final VoidCallback? onBad;

  /// Shows a share action when non-null.
  ///
  /// The package ships no share implementation (it has no platform plugins);
  /// wire your own, e.g. with `share_plus`:
  /// `onShare: () => Share.share(message.text)`.
  final VoidCallback? onShare;

  /// Shows a Regenerate action when non-null.
  final VoidCallback? onRegenerate;

  /// Shows an Edit action when non-null.
  final VoidCallback? onEdit;

  /// Size of the action icons.
  final double iconSize;

  /// The order actions are rendered in.
  final List<AiMessageActionKind> order;

  /// Actions pushed to the far (end) side, after a spacer. When non-empty the
  /// row expands to fill its width so the split is visible.
  final Set<AiMessageActionKind> trailing;

  void _copy() {
    if (onCopy != null) {
      onCopy!();
    } else {
      unawaited(Clipboard.setData(ClipboardData(text: message.text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AiLocalizations.of(context);
    final color = DefaultTextStyle.of(context).style.color?.withValues(
          alpha: 0.6,
        );
    // Compact, evenly spaced icon buttons (ChatGPT-style): a uniform 36px target
    // with tight, equal padding rather than the default ~48px IconButton gaps.
    Widget button(IconData icon, String tooltip, VoidCallback onPressed) {
      return IconButton(
        icon: Icon(icon, size: iconSize),
        color: color,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        style: const ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onPressed,
      );
    }

    // Resolve each kind to a button, or null when its callback is absent (copy
    // always renders, defaulting to clipboard).
    Widget? forKind(AiMessageActionKind kind) => switch (kind) {
          AiMessageActionKind.copy => button(Icons.copy_rounded, l.copy, _copy),
          AiMessageActionKind.speak => onSpeak == null
              ? null
              : button(Icons.volume_up_outlined, l.readAloud, onSpeak!),
          AiMessageActionKind.good => onGood == null
              ? null
              : button(Icons.thumb_up_outlined, l.goodResponse, onGood!),
          AiMessageActionKind.bad => onBad == null
              ? null
              : button(Icons.thumb_down_outlined, l.badResponse, onBad!),
          AiMessageActionKind.share => onShare == null
              ? null
              : button(Icons.ios_share_rounded, l.share, onShare!),
          AiMessageActionKind.regenerate => onRegenerate == null
              ? null
              : button(Icons.refresh_rounded, l.regenerate, onRegenerate!),
          AiMessageActionKind.edit => onEdit == null
              ? null
              : button(Icons.edit_outlined, l.edit, onEdit!),
        };

    final leading = <Widget>[];
    final tail = <Widget>[];
    for (final kind in order) {
      final w = forKind(kind);
      if (w == null) continue;
      (trailing.contains(kind) ? tail : leading).add(w);
    }

    if (tail.isEmpty) {
      return Row(mainAxisSize: MainAxisSize.min, children: leading);
    }
    return Row(children: [...leading, const Spacer(), ...tail]);
  }
}

/// Presents the per-message actions in a native bottom sheet — the idiomatic
/// mobile pattern, triggered from a long-press on a message.
Future<void> showAiMessageActions(
  BuildContext context, {
  required AiMessage message,
  VoidCallback? onCopy,
  VoidCallback? onRegenerate,
  VoidCallback? onEdit,
}) {
  final l = AiLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      // Scrollable so the actions never overflow in landscape / small heights.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l.copy),
              onTap: () {
                if (onCopy != null) {
                  onCopy();
                } else {
                  unawaited(
                      Clipboard.setData(ClipboardData(text: message.text)));
                }
                Navigator.of(sheetContext).pop();
              },
            ),
            if (onRegenerate != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l.regenerate),
                onTap: () {
                  onRegenerate();
                  Navigator.of(sheetContext).pop();
                },
              ),
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l.edit),
                onTap: () {
                  onEdit();
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

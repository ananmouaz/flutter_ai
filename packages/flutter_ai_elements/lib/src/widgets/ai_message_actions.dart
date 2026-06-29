import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';

/// A compact row of per-message actions: copy, and optionally regenerate and
/// edit.
///
/// Copy defaults to placing the message's text on the clipboard; override it via
/// [onCopy]. On mobile, prefer presenting these via [showAiMessageActions] from
/// a long-press rather than always-visible buttons.
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
  final VoidCallback? onShare;

  /// Shows a Regenerate action when non-null.
  final VoidCallback? onRegenerate;

  /// Shows an Edit action when non-null.
  final VoidCallback? onEdit;

  /// Size of the action icons.
  final double iconSize;

  void _copy() {
    if (onCopy != null) {
      onCopy!();
    } else {
      unawaited(Clipboard.setData(ClipboardData(text: message.text)));
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.copy_rounded, 'Copy', _copy),
        if (onSpeak != null)
          button(Icons.volume_up_outlined, 'Read aloud', onSpeak!),
        if (onGood != null)
          button(Icons.thumb_up_outlined, 'Good response', onGood!),
        if (onBad != null)
          button(Icons.thumb_down_outlined, 'Bad response', onBad!),
        if (onShare != null) button(Icons.ios_share_rounded, 'Share', onShare!),
        if (onRegenerate != null)
          button(Icons.refresh_rounded, 'Regenerate', onRegenerate!),
        if (onEdit != null) button(Icons.edit_outlined, 'Edit', onEdit!),
      ],
    );
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
              title: const Text('Copy'),
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
                title: const Text('Regenerate'),
                onTap: () {
                  onRegenerate();
                  Navigator.of(sheetContext).pop();
                },
              ),
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
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

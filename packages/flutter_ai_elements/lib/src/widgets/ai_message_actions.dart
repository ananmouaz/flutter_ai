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
    this.onRegenerate,
    this.onEdit,
    this.iconSize = 18,
  });

  /// The message these actions apply to.
  final AiMessage message;

  /// Overrides the default copy-to-clipboard behavior.
  final VoidCallback? onCopy;

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
          alpha: 0.7,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.copy, size: iconSize),
          color: color,
          tooltip: 'Copy',
          onPressed: _copy,
        ),
        if (onRegenerate != null)
          IconButton(
            icon: Icon(Icons.refresh, size: iconSize),
            color: color,
            tooltip: 'Regenerate',
            onPressed: onRegenerate,
          ),
        if (onEdit != null)
          IconButton(
            icon: Icon(Icons.edit_outlined, size: iconSize),
            color: color,
            tooltip: 'Edit',
            onPressed: onEdit,
          ),
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
                unawaited(Clipboard.setData(ClipboardData(text: message.text)));
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
  );
}

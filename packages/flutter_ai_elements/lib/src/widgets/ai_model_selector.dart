import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A selectable model option.
@immutable
class AiModelOption {
  /// Creates a model option.
  const AiModelOption({
    required this.id,
    required this.label,
    this.description,
  });

  /// The stable identifier passed to the provider.
  final String id;

  /// The display name.
  final String label;

  /// An optional one-line description shown in the picker.
  final String? description;
}

/// A compact "model ▾" chip that opens a bottom sheet to switch models.
///
/// Wire [onSelected] to `UseChatController.setOptions` (or your own state) to
/// change the active model.
class AiModelSelector extends StatelessWidget {
  /// Creates a model selector.
  const AiModelSelector({
    super.key,
    required this.models,
    required this.selectedId,
    required this.onSelected,
  });

  /// The available models.
  final List<AiModelOption> models;

  /// The id of the currently selected model.
  final String selectedId;

  /// Called with the chosen model id.
  final ValueChanged<String> onSelected;

  AiModelOption get _selected => models.firstWhere(
        (m) => m.id == selectedId,
        orElse: () => models.first,
      );

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    return GestureDetector(
      onTap: () => unawaited(_open(context)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selected.label,
              style: theme.textStyle.copyWith(fontSize: 13, color: color),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) {
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
            for (final model in models)
              ListTile(
                title: Text(model.label),
                subtitle:
                    model.description == null ? null : Text(model.description!),
                trailing: model.id == selectedId
                    ? const Icon(Icons.check, color: Color(0xFF16A34A))
                    : null,
                onTap: () {
                  onSelected(model.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

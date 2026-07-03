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
    this.labelStyle,
    this.labelBuilder,
    this.showBorder = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  /// The available models.
  final List<AiModelOption> models;

  /// The id of the currently selected model.
  final String selectedId;

  /// Called with the chosen model id.
  final ValueChanged<String> onSelected;

  /// Style for the trigger's label text. Merged over the themed default (which
  /// is `theme.textStyle` at size 13). Ignored when [labelBuilder] is set.
  final TextStyle? labelStyle;

  /// Fully replaces the trigger's label+chevron with a custom widget (e.g. a
  /// larger two-tone brand title). The chevron is *not* added automatically —
  /// include your own. The picker sheet is still opened on tap.
  final Widget Function(BuildContext context, AiModelOption selected)?
      labelBuilder;

  /// Whether to draw the rounded border around the trigger. Turn off for a
  /// borderless brand title.
  final bool showBorder;

  /// Padding inside the trigger.
  final EdgeInsets padding;

  AiModelOption? get _selected {
    if (models.isEmpty) return null;
    return models.firstWhere(
      (m) => m.id == selectedId,
      orElse: () => models.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    // Nothing to select yet (e.g. models still loading) — render nothing.
    final selected = _selected;
    if (selected == null) return const SizedBox.shrink();
    final color = DefaultTextStyle.of(context).style.color;
    return Semantics(
      button: true,
      label: 'Select model, ${selected.label}',
      child: GestureDetector(
        onTap: () => unawaited(_open(context)),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: showBorder ? Border.all(color: theme.borderColor) : null,
          ),
          child: labelBuilder != null
              ? labelBuilder!(context, selected)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selected.label,
                      style: theme.textStyle
                          .copyWith(fontSize: 13, color: color)
                          .merge(labelStyle),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.expand_more, size: 16, color: color),
                  ],
                ),
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
      // Bounded + scrollable so a long model list (or landscape) doesn't
      // overflow the sheet.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final model in models)
                ListTile(
                  title: Text(model.label),
                  subtitle: model.description == null
                      ? null
                      : Text(model.description!),
                  trailing: model.id == selectedId
                      ? Icon(
                          Icons.check,
                          color: AiThemeExtension.of(sheetContext).successColor,
                        )
                      : null,
                  onTap: () {
                    onSelected(model.id);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A small numbered citation badge (e.g. `1`) shown inline with text or after a
/// claim, tappable to open or reveal the source.
///
/// Compose it into rich text with a `WidgetSpan`, or place it in a row of
/// citations.
class AiInlineCitation extends StatelessWidget {
  /// Creates a citation badge for [number].
  const AiInlineCitation({super.key, required this.number, this.onTap});

  /// The 1-based citation index.
  final int number;

  /// Called when the badge is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.assistantBubbleColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.borderColor),
        ),
        child: Text(
          '$number',
          style: theme.codeStyle.copyWith(
            fontSize: 11,
            height: 1,
            color: color?.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

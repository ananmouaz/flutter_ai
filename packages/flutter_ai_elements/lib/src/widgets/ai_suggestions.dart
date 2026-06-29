import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';
import 'package:flutter_ai_elements/src/widgets/ai_haptics.dart';

/// A horizontally scrolling row of tappable suggested prompts.
///
/// Useful as a conversation starter or for follow-up suggestions; tapping a chip
/// invokes [onSelected] with its text.
class AiSuggestions extends StatelessWidget {
  /// Creates a suggestions strip.
  const AiSuggestions({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  /// The prompt texts to offer.
  final List<String> suggestions;

  /// Called with the chosen suggestion.
  final ValueChanged<String> onSelected;

  /// Padding around the strip.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _Chip(
              label: suggestions[i],
              theme: theme,
              onTap: () {
                aiLightHaptic(theme);
                onSelected(suggestions[i]);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.theme, required this.onTap});

  final String label;
  final AiThemeExtension theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.assistantBubbleColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(color: theme.assistantTextColor),
          ),
        ),
      ),
    );
  }
}

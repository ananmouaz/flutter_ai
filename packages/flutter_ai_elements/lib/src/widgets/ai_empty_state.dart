import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';
import 'package:flutter_ai_elements/src/widgets/ai_haptics.dart';

/// A centered placeholder shown when a conversation has no messages yet.
///
/// Beyond a title/subtitle it can show a brand [glyph] (or a default [icon])
/// and a set of tappable [suggestions] that seed the first turn via
/// [onSuggestionTap] — the conversation-starter pattern from modern assistants.
/// Fully themed via [AiThemeExtension].
class AiEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const AiEmptyState({
    super.key,
    this.title = 'Start the conversation',
    this.subtitle,
    this.icon = Icons.chat_bubble_outline,
    this.glyph,
    this.suggestions = const [],
    this.onSuggestionTap,
  });

  /// The primary headline.
  final String title;

  /// Optional supporting line beneath the title.
  final String? subtitle;

  /// The icon shown above the title when [glyph] is null.
  final IconData icon;

  /// An optional brand widget shown in place of [icon] (e.g. a logo).
  final Widget? glyph;

  /// Conversation-starter prompts shown as tappable chips. Empty hides them.
  final List<String> suggestions;

  /// Called with the chosen suggestion's text. Required for the chips to be
  /// interactive; without it the chips render but don't respond.
  final ValueChanged<String>? onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    final muted = color?.withValues(alpha: 0.6);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph ?? Icon(icon, size: 48, color: muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textStyle.copyWith(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textStyle.copyWith(color: muted),
              ),
            ],
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in suggestions)
                    _SuggestionChip(
                      label: s,
                      theme: theme,
                      onTap: onSuggestionTap == null
                          ? null
                          : () {
                              aiLightHaptic(theme);
                              onSuggestionTap!(s);
                            },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final AiThemeExtension theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.assistantBubbleColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: theme.textStyle.copyWith(
              color: theme.assistantTextColor,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

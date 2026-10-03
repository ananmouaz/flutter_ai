import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';
import 'package:flutter_ai_elements/src/widgets/ai_haptics.dart';

/// How [AiSuggestions] arranges its prompts.
enum AiSuggestionsLayout {
  /// A single horizontally scrolling row of chips.
  row,

  /// Full-width, divided rows — suited to follow-up questions under an answer.
  /// Long prompts wrap instead of scrolling out of view.
  list,

  /// A grid of starter cards (two columns, or one on narrow screens and at
  /// large text sizes) — suited to an empty conversation. It measures its
  /// width with a `LayoutBuilder`, so do not place it under a parent that asks
  /// for intrinsic sizes (`IntrinsicHeight`, `SliverFillRemaining` without a
  /// scroll body); use a `SingleChildScrollView` with a min-height instead.
  grid,
}

/// Tappable suggested prompts, as a chip row, full-width list or starter grid.
///
/// Useful as a conversation starter or for follow-up suggestions; tapping a
/// suggestion invokes [onSelected] with its text.
class AiSuggestions extends StatelessWidget {
  /// Creates a suggestions strip.
  const AiSuggestions({
    super.key,
    required this.suggestions,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.layout = AiSuggestionsLayout.row,
  });

  /// The prompt texts to offer.
  final List<String> suggestions;

  /// Called with the chosen suggestion. Null renders the suggestions disabled,
  /// e.g. while a response is streaming.
  final ValueChanged<String>? onSelected;

  /// Padding around the suggestions.
  final EdgeInsets padding;

  /// How the suggestions are arranged. Defaults to [AiSuggestionsLayout.row].
  final AiSuggestionsLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    VoidCallback? tap(String s) => onSelected == null
        ? null
        : () {
            aiLightHaptic(theme);
            onSelected!(s);
          };
    return switch (layout) {
      AiSuggestionsLayout.row => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: Row(
            children: [
              for (var i = 0; i < suggestions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _Chip(
                  label: suggestions[i],
                  theme: theme,
                  onTap: tap(suggestions[i]),
                ),
              ],
            ],
          ),
        ),
      AiSuggestionsLayout.list => Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < suggestions.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: theme.borderColor),
                _ListRow(
                  label: suggestions[i],
                  theme: theme,
                  onTap: tap(suggestions[i]),
                ),
              ],
            ],
          ),
        ),
      AiSuggestionsLayout.grid => Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Two columns only when each card keeps a readable measure at
              // the current text size; otherwise stack them.
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final columns = constraints.maxWidth / scale >= 300 ? 2 : 1;
              final cards = [
                for (final s in suggestions)
                  _GridCard(label: s, theme: theme, onTap: tap(s)),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < cards.length; i += columns) ...[
                    if (i > 0) const SizedBox(height: 8),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var j = i; j < i + columns; j++) ...[
                            if (j > i) const SizedBox(width: 8),
                            Expanded(
                              child: j < cards.length
                                  ? cards[j]
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
    };
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.theme, required this.onTap});

  final String label;
  final AiThemeExtension theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: theme.effectiveChipColor,
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
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final AiThemeExtension theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = theme.assistantTextColor;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Transform.flip(
                      flipX: rtl,
                      child: Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 18,
                        color: fg.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textStyle.copyWith(
                        color: onTap == null ? fg.withValues(alpha: 0.5) : fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final AiThemeExtension theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: theme.effectiveChipColor,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: theme.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Text(
                  label,
                  style: theme.textStyle.copyWith(
                    color: theme.assistantTextColor,
                    fontSize: 14.5,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

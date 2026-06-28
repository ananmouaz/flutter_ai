import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A compact "‹ 2/3 ›" control for navigating between alternate versions of a
/// message (e.g. successive regenerations).
///
/// Purely presentational: it reports navigation via [onPrevious]/[onNext] and
/// shows [index] of [total] (both 1-based for display; pass a 0-based [index]).
class AiBranch extends StatelessWidget {
  /// Creates a branch navigator.
  const AiBranch({
    super.key,
    required this.index,
    required this.total,
    this.onPrevious,
    this.onNext,
  });

  /// The 0-based index of the current version.
  final int index;

  /// The total number of versions.
  final int total;

  /// Called to go to the previous version. Disabled at the first.
  final VoidCallback? onPrevious;

  /// Called to go to the next version. Disabled at the last.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color?.withValues(
          alpha: 0.7,
        );
    final canPrev = index > 0 && onPrevious != null;
    final canNext = index < total - 1 && onNext != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Arrow(
          icon: Icons.chevron_left,
          label: 'Previous version',
          color: color,
          onTap: canPrev ? onPrevious : null,
        ),
        Text(
          '${index + 1}/$total',
          style: theme.codeStyle.copyWith(fontSize: 12, color: color),
        ),
        _Arrow(
          icon: Icons.chevron_right,
          label: 'Next version',
          color: color,
          onTap: canNext ? onNext : null,
        ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? color?.withValues(alpha: 0.3) : color,
          ),
        ),
      ),
    );
  }
}

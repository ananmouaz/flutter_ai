import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A compact context-window usage meter: a label, a `used / total` token
/// readout, and a thin progress bar that turns amber/red as it fills.
class AiContextMeter extends StatelessWidget {
  /// Creates a usage meter.
  const AiContextMeter({
    super.key,
    required this.usedTokens,
    required this.totalTokens,
    this.label = 'Context',
  });

  /// Tokens used so far.
  final int usedTokens;

  /// The context-window size.
  final int totalTokens;

  /// Leading label.
  final String label;

  double get _fraction =>
      totalTokens <= 0 ? 0 : (usedTokens / totalTokens).clamp(0, 1);

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    final fraction = _fraction;
    final barColor = fraction > 0.9
        ? theme.errorColor
        : fraction > 0.7
            ? theme.warningColor
            : theme.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color?.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Text(
              '${_fmt(usedTokens)} / ${_fmt(totalTokens)}',
              style: theme.codeStyle.copyWith(
                fontSize: 12,
                color: color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 6, color: theme.borderColor),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(height: 6, color: barColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

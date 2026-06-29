import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// An animated shimmer placeholder for pending content — a row of grey bars
/// with a highlight sweeping across them.
class AiShimmer extends StatefulWidget {
  /// Creates a shimmer with [lines] placeholder bars.
  const AiShimmer({super.key, this.lines = 3, this.spacing = 10});

  /// Number of placeholder bars.
  final int lines;

  /// Vertical gap between bars.
  final double spacing;

  @override
  State<AiShimmer> createState() => _AiShimmerState();
}

class _AiShimmerState extends State<AiShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final base = theme.borderColor;
    // A clearly lighter sweep that works in both light and dark themes.
    final highlight = Color.lerp(base, Colors.white, 0.5)!;

    return Semantics(
      label: AiLocalizations.of(context).loading,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Travel the highlight fully across (off-left → off-right) so the
          // loop is seamless — it's off-screen at both ends.
          final c = -1.5 + 3.0 * _controller.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(c - 0.7, 0),
              end: Alignment(c + 0.7, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(rect),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.lines; i++) ...[
              if (i > 0) SizedBox(height: widget.spacing),
              FractionallySizedBox(
                widthFactor: i == widget.lines - 1 ? 0.55 : 1,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

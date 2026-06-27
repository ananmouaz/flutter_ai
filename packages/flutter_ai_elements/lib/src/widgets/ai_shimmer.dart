import 'package:flutter/material.dart';
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
    final highlight = theme.assistantBubbleColor;

    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 - 2 * (1 - t), 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
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

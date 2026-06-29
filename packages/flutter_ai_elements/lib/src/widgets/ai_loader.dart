import 'package:flutter/widgets.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A three-dot "thinking" indicator shown while the assistant is preparing a
/// response.
///
/// The dots pulse in sequence using the theme's loader color and motion timing.
class AiLoader extends StatefulWidget {
  /// Creates a loader.
  const AiLoader({super.key, this.dotSize = 8, this.dotSpacing = 4});

  /// Diameter of each dot.
  final double dotSize;

  /// Horizontal gap between dots.
  final double dotSpacing;

  @override
  State<AiLoader> createState() => _AiLoaderState();
}

class _AiLoaderState extends State<AiLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    return Semantics(
      label: AiLocalizations.of(context).thinking,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(
                  right: i == 2 ? 0 : widget.dotSpacing,
                ),
                child: _dot(theme.loaderColor, _opacityForDot(i)),
              ),
          ],
        ),
      ),
    );
  }

  // Each dot is a third of a cycle out of phase with the previous one.
  double _opacityForDot(int index) {
    final phase = (_controller.value + index / 3) % 1.0;
    // Triangle wave: 0 -> 1 -> 0 across the cycle.
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.3 + 0.7 * wave;
  }

  Widget _dot(Color color, double opacity) => Container(
        width: widget.dotSize,
        height: widget.dotSize,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );
}

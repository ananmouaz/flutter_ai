import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A small, calm voice/loading **orb** — a luminous sphere that gently breathes
/// and reacts to audio [amplitude]. The compact counterpart to the full-screen
/// orb in `AiLiveSession`, usable inline (e.g. in a composer or status row).
///
/// Colors derive from [AiThemeExtension.orbColor] and the size from [size];
/// both are fully themeable. Under reduce-motion the breathing stops and a
/// static sphere is shown (WCAG 2.3.3).
class AiOrb extends StatefulWidget {
  /// Creates an orb of diameter [size].
  const AiOrb({super.key, this.size = 64, this.amplitude = 0});

  /// Diameter of the orb in logical pixels.
  final double size;

  /// Normalized audio level (`0`–`1`) the orb reacts to. `0` is calm.
  final double amplitude;

  @override
  State<AiOrb> createState() => _AiOrbState();
}

class _AiOrbState extends State<AiOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final react = widget.amplitude.clamp(0.0, 1.0);
    if (_reduceMotion) {
      return _sphere(theme.orbColor, breathe: 0, react: react);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final breathe = 0.5 - 0.5 * math.cos(2 * math.pi * _controller.value);
        return _sphere(theme.orbColor, breathe: breathe, react: react);
      },
    );
  }

  Widget _sphere(Color base, {required double breathe, required double react}) {
    final light = Color.lerp(base, Colors.white, 0.7)!;
    final dark = Color.lerp(base, Colors.black, 0.35)!;
    final d = widget.size * (1 + 0.04 * breathe + 0.16 * react);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.45),
              radius: 1.15,
              colors: [light, base, dark],
              stops: const [0.0, 0.65, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: base.withValues(
                  alpha: 0.30 + 0.28 * react + 0.08 * breathe,
                ),
                blurRadius: widget.size * (0.4 + 0.4 * react),
                spreadRadius: widget.size * 0.03 * (1 + react),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

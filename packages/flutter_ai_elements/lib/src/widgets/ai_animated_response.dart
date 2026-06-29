import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ai_elements/src/widgets/ai_response.dart';

/// Wraps [AiResponse] with a light typewriter reveal so streamed answers appear
/// smoothly and gradually rather than snapping in token-by-token.
///
/// It renders an ever-growing prefix of [text], advancing the visible length
/// toward the full text at [charsPerSecond]. When the stream outpaces the
/// reveal, the reveal simply keeps catching up; when the text is complete it
/// finishes revealing and stops. Use it for the *streaming* message only —
/// completed/history messages should use [AiResponse] directly so they don't
/// replay the animation.
class AiAnimatedResponse extends StatefulWidget {
  /// Creates an animated Markdown response.
  const AiAnimatedResponse({
    super.key,
    required this.text,
    this.onLinkTap,
    this.charsPerSecond = 1200,
  });

  /// The (growing) Markdown source to reveal.
  final String text;

  /// Forwarded to [AiResponse.onLinkTap].
  final void Function(Uri url)? onLinkTap;

  /// How fast the reveal advances. Tuned to keep up with typical token rates
  /// while still smoothing the per-token jumps.
  final double charsPerSecond;

  @override
  State<AiAnimatedResponse> createState() => _AiAnimatedResponseState();
}

class _AiAnimatedResponseState extends State<AiAnimatedResponse>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _shown = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    if (widget.text.isNotEmpty) unawaited(_ticker.start());
  }

  @override
  void didUpdateWidget(AiAnimatedResponse oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the text was replaced (e.g. a regenerate) rather than appended to,
    // restart the reveal from the beginning.
    if (!widget.text.startsWith(oldWidget.text.substring(
      0,
      math.min(oldWidget.text.length, widget.text.length),
    ))) {
      _shown = 0;
    }
    if (_shown < widget.text.length && !_ticker.isActive) {
      _last = Duration.zero;
      unawaited(_ticker.start());
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    final target = widget.text.length;
    final step = math.max(1, (widget.charsPerSecond * dt).round());
    final next = _shown + step < target ? _shown + step : target;
    if (next != _shown) setState(() => _shown = next);
    if (_shown >= target) {
      _ticker.stop();
      _last = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown < widget.text.length ? _shown : widget.text.length;
    return AiResponse(
      text: widget.text.substring(0, shown),
      onLinkTap: widget.onLinkTap,
    );
  }
}

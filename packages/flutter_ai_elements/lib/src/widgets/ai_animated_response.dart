import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// Reveals a streamed answer with a trailing **blur fade-in** — the
/// Apple-Intelligence / Siri look — instead of a hard typewriter edge.
///
/// Text appears progressively (paced like [charsPerSecond], accelerating to
/// drain a backlog within [catchUpWindow] so it never trails far behind a fast
/// stream), and each newly revealed word arrives blurred and semi-transparent,
/// then sharpens and fades into place over [fadeDuration]. Only the few words
/// at the leading edge animate at once, so the cost stays bounded no matter how
/// long the answer is.
///
/// This renders the in-flight text as **plain prose** (no Markdown formatting)
/// — inline blur can only be applied to whole inline boxes, not to spans inside
/// a laid-out paragraph. Use it for the *streaming* message only; completed
/// messages should render with the full Markdown widget so headings, lists,
/// code, and links come back.
class AiAnimatedResponse extends StatefulWidget {
  /// Creates an animated Markdown response.
  const AiAnimatedResponse({
    super.key,
    required this.text,
    this.onLinkTap,
    this.charsPerSecond = 120,
    this.catchUpWindow = const Duration(seconds: 1),
    this.fadeDuration = const Duration(milliseconds: 340),
    this.blurSigma = 5,
  });

  /// The (growing) source text to reveal.
  final String text;

  /// Reserved for API compatibility with the completed renderer. Links are not
  /// tappable during the animated phase (the in-flight text is plain prose);
  /// they become active once the message settles into the Markdown renderer.
  final void Function(Uri url)? onLinkTap;

  /// The baseline (readable) reveal speed used while the typewriter is keeping
  /// up with the stream feeding it. Tuned to a comfortable reading pace.
  final double charsPerSecond;

  /// When the reveal falls behind the stream, it accelerates so the remaining
  /// backlog drains within this window — keeping the pace readable on slow
  /// streams while never trailing far behind a fast one.
  final Duration catchUpWindow;

  /// How long each freshly revealed word takes to sharpen from blurred and
  /// faded to crisp and opaque.
  final Duration fadeDuration;

  /// The blur applied to a word the moment it appears, in logical pixels. It
  /// eases to zero over [fadeDuration].
  final double blurSigma;

  @override
  State<AiAnimatedResponse> createState() => _AiAnimatedResponseState();
}

class _AiAnimatedResponseState extends State<AiAnimatedResponse>
    with SingleTickerProviderStateMixin {
  /// At most this many trailing words animate at once, bounding the number of
  /// blur/opacity layers regardless of how fast the stream bursts.
  static const _maxAnimating = 6;

  late final Ticker _ticker;

  /// `[start, end)` char ranges of every non-whitespace run in the text.
  List<List<int>> _words = const [];

  /// Word start offset -> the ticker time at which it became fully revealed.
  final Map<int, Duration> _births = {};

  int _shown = 0; // characters revealed so far
  int _settledCursor = 0; // index into [_words] whose births are recorded
  Duration _last = Duration.zero;
  Duration _elapsed = Duration.zero;

  @visibleForTesting
  int get shownChars => _shown;

  @override
  void initState() {
    super.initState();
    _retokenize();
    _ticker = createTicker(_tick);
    if (widget.text.isNotEmpty) unawaited(_ticker.start());
  }

  void _retokenize() {
    final s = widget.text;
    final words = <List<int>>[];
    var i = 0;
    while (i < s.length) {
      if (_isSpace(s.codeUnitAt(i))) {
        i++;
        continue;
      }
      final start = i;
      while (i < s.length && !_isSpace(s.codeUnitAt(i))) {
        i++;
      }
      words.add([start, i]);
    }
    _words = words;
  }

  static bool _isSpace(int c) =>
      c == 0x20 || c == 0x0A || c == 0x09 || c == 0x0D;

  @override
  void didUpdateWidget(AiAnimatedResponse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    // If the text was replaced (e.g. a regenerate) rather than appended to,
    // restart the reveal from the beginning.
    final appended = widget.text.startsWith(oldWidget.text.substring(
      0,
      math.min(oldWidget.text.length, widget.text.length),
    ));
    _retokenize();
    if (!appended) {
      _shown = 0;
      _settledCursor = 0;
      _births.clear();
    }
    if (!_settled() && !_ticker.isActive) {
      _last = Duration.zero;
      unawaited(_ticker.start());
    }
  }

  /// True once everything is revealed and the last word has finished sharpening.
  bool _settled() {
    if (_shown < widget.text.length) return false;
    if (_words.isEmpty) return true;
    final birth = _births[_words.last[0]];
    if (birth == null) return false;
    return (_elapsed - birth) >= widget.fadeDuration;
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    _elapsed = elapsed;

    final target = widget.text.length;
    // Reveal at the readable baseline while caught up, but accelerate to drain
    // a large backlog within [catchUpWindow] so the typewriter never trails far
    // behind the stream once the answer has fully arrived.
    final window =
        widget.catchUpWindow.inMicroseconds / Duration.microsecondsPerSecond;
    final backlogRate =
        window > 0 ? (target - _shown) / window : double.infinity;
    final rate = math.max(widget.charsPerSecond, backlogRate);
    final step = math.max(1, (rate * dt).round());
    _shown = _shown + step < target ? _shown + step : target;

    // Stamp the birth time of every word that just became fully revealed.
    while (
        _settledCursor < _words.length && _words[_settledCursor][1] <= _shown) {
      _births.putIfAbsent(_words[_settledCursor][0], () => elapsed);
      _settledCursor++;
    }

    if (_settled()) {
      _ticker.stop();
      _last = Duration.zero;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);
    final text = widget.text;

    // Respect the platform "reduce motion" setting: skip the blur/typewriter
    // and show the text as-is (an accessibility requirement, WCAG 2.3.3).
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Text(text, style: base);
    }

    final visible = math.min(_shown, text.length);

    // Index of the last word that is fully revealed; only the trailing
    // [_maxAnimating] of these (plus any partially revealed word) animate.
    var lastFull = -1;
    for (var i = 0; i < _words.length; i++) {
      if (_words[i][1] <= visible) {
        lastFull = i;
      } else {
        break;
      }
    }
    final animateFrom = lastFull - _maxAnimating + 1;

    final spans = <InlineSpan>[];
    final settled = StringBuffer();
    var cursor = 0;
    for (var i = 0; i < _words.length; i++) {
      final start = _words[i][0];
      final end = _words[i][1];
      if (start >= visible) break;
      if (start > cursor) settled.write(text.substring(cursor, start));
      final shownEnd = math.min(end, visible);
      final partial = end > visible;

      double t; // 0 = just born (blurred), 1 = settled (crisp)
      if (partial) {
        t = 0;
      } else {
        final birth = _births[start];
        t = birth == null
            ? 1
            : ((_elapsed - birth).inMicroseconds /
                    widget.fadeDuration.inMicroseconds)
                .clamp(0.0, 1.0);
      }

      final recent = i >= animateFrom;
      if (t >= 1.0 || (!partial && !recent)) {
        settled.write(text.substring(start, shownEnd));
      } else {
        if (settled.isNotEmpty) {
          spans.add(TextSpan(text: settled.toString(), style: base));
          settled.clear();
        }
        final eased = Curves.easeOut.transform(t);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Opacity(
            opacity: 0.25 + 0.75 * eased,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: widget.blurSigma * (1 - eased),
                sigmaY: widget.blurSigma * (1 - eased),
                tileMode: TileMode.decal,
              ),
              child: Text(text.substring(start, shownEnd), style: base),
            ),
          ),
        ));
      }
      cursor = shownEnd;
    }
    if (cursor < visible) settled.write(text.substring(cursor, visible));
    if (settled.isNotEmpty) {
      spans.add(TextSpan(text: settled.toString(), style: base));
    }

    // A blinking caret at the leading edge — the "being written right now" cue.
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: _Caret(
        key: const ValueKey('ai-caret'),
        color: base.color ?? const Color(0xFF000000),
        base: base,
      ),
    ));

    // Isolate the per-frame repaint of the animating reveal from the rest of
    // the message/list so the blur layers don't dirty their neighbors.
    return RepaintBoundary(
      child: Text.rich(TextSpan(children: spans, style: base)),
    );
  }
}

/// A thin blinking text caret. Holds steady (no blink) under reduce-motion.
class _Caret extends StatefulWidget {
  const _Caret({super.key, required this.color, required this.base});

  final Color color;
  final TextStyle base;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = (widget.base.fontSize ?? 16) * (widget.base.height ?? 1.2);
    final bar = Padding(
      padding: const EdgeInsetsDirectional.only(start: 1),
      child: Container(width: 2, height: height * 0.78, color: widget.color),
    );
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return bar;
    return FadeTransition(
      // Square wave-ish blink: mostly on, brief off.
      opacity: _blink.drive(
        TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween(1), weight: 55),
          TweenSequenceItem(tween: ConstantTween(0), weight: 45),
        ]),
      ),
      child: bar,
    );
  }
}

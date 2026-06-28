import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// The phase of a live voice session.
enum AiLiveStatus {
  /// Establishing the session.
  connecting,

  /// Listening to the user.
  listening,

  /// Processing.
  thinking,

  /// The assistant is speaking.
  speaking,

  /// The session has ended.
  ended,
}

/// A full-screen, engine-agnostic **Live voice** surface, modelled on modern
/// assistant voice modes: a luminous sky-orb that opens centered, then *drops
/// and shrinks* to dock above the controls while the [conversation] fades in
/// behind it so you can read along. The orb's interior is an animated,
/// cloud-lit sky that breathes and reacts to audio [amplitude].
///
/// Purely presentational: drive [status] and [amplitude] from your audio engine
/// (realtime STT/TTS) and handle the control callbacks. It paints its own dark,
/// immersive background and fills its parent — wrap it in a `Scaffold` for
/// full-screen use.
class AiLiveSession extends StatefulWidget {
  /// Creates a live session surface.
  const AiLiveSession({
    super.key,
    this.status = AiLiveStatus.listening,
    this.amplitude = 0,
    this.transcript,
    this.conversation,
    this.muted = false,
    this.onMute,
    this.onKeyboard,
    this.onEnd,
  });

  /// The current phase.
  final AiLiveStatus status;

  /// Normalized audio level (`0`–`1`) driving the orb's reaction.
  final double amplitude;

  /// Live transcript text shown briefly under the centered orb (before docking).
  final String? transcript;

  /// The scrolling conversation to reveal behind the docked orb. When non-null,
  /// the orb drops and shrinks shortly after opening to make room for it.
  final Widget? conversation;

  /// Whether the mic is muted.
  final bool muted;

  /// Toggles mute. Hidden if `null`.
  final VoidCallback? onMute;

  /// Switches back to the text composer. Hidden if `null`.
  final VoidCallback? onKeyboard;

  /// Ends the session. Hidden if `null`.
  final VoidCallback? onEnd;

  @override
  State<AiLiveSession> createState() => _AiLiveSessionState();
}

class _AiLiveSessionState extends State<AiLiveSession>
    with TickerProviderStateMixin {
  // Gentle pulse.
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  // Opening pop (fade + scale-in).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  // Centered → docked (drop + shrink) with the conversation revealed.
  late final AnimationController _dock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  Timer? _dockTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_intro.forward());
    // The orb opens centered, then drops and shrinks to dock above the controls.
    _dockTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) unawaited(_dock.forward());
    });
  }

  @override
  void dispose() {
    _dockTimer?.cancel();
    _breathe.dispose();
    _intro.dispose();
    _dock.dispose();
    super.dispose();
  }

  String get _label => switch (widget.status) {
        AiLiveStatus.connecting => 'Connecting…',
        AiLiveStatus.listening => 'Listening',
        AiLiveStatus.thinking => 'Thinking…',
        AiLiveStatus.speaking => 'Speaking',
        AiLiveStatus.ended => '',
      };

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final active = widget.status == AiLiveStatus.speaking ||
        widget.status == AiLiveStatus.listening;

    // Immersive dark surface (voice mode is a focused, dark experience).
    return ColoredBox(
      color: const Color(0xFF000000),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            // Static subtree — does NOT depend on the animation, so it is built
            // once and handed to the AnimatedBuilder via `child:` instead of
            // rebuilding at 60fps with the orb.
            final controls = Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.onKeyboard != null)
                    _CircleButton(
                      icon: Icons.keyboard_outlined,
                      label: 'Keyboard',
                      onTap: widget.onKeyboard,
                    ),
                  if (widget.onMute != null)
                    _CircleButton(
                      icon:
                          widget.muted ? Icons.mic_off : Icons.mic_none_rounded,
                      label: widget.muted ? 'Unmute' : 'Mute',
                      onTap: widget.onMute,
                    ),
                  if (widget.onEnd != null)
                    _CircleButton(
                      icon: Icons.close,
                      label: 'End',
                      onTap: widget.onEnd,
                      filled: true,
                    ),
                ],
              ),
            );

            return AnimatedBuilder(
              animation: Listenable.merge([_breathe, _intro, _dock]),
              // The conversation/control subtree is the static child; only the
              // orb and the animated opacities/positions are rebuilt per frame.
              child: controls,
              builder: (context, child) {
                final intro = Curves.easeOut.transform(_intro.value);
                final dock = Curves.easeOutCubic.transform(_dock.value);
                final breathe =
                    0.5 - 0.5 * math.cos(2 * math.pi * _breathe.value);
                final amp = (widget.muted ? 0.0 : widget.amplitude).clamp(0, 1);
                final react = (active ? amp : amp * 0.3).toDouble();

                // Big and centered while listening; a small ball once docked.
                final base = lerpDouble(240, 92, dock)!;
                final orb = base *
                    (1 + 0.04 * breathe + 0.16 * react) *
                    (0.86 + 0.14 * intro);
                final centerY = lerpDouble(h * 0.44, h * 0.70, dock)!;
                final top = centerY - orb / 2;

                return Stack(
                  children: [
                    // Readable area above the docked orb: the conversation if
                    // given, otherwise the live transcript. Fades in as it docks.
                    if (widget.conversation != null ||
                        widget.transcript != null)
                      Positioned(
                        top: 52,
                        left: 0,
                        right: 0,
                        bottom: h - top + 12,
                        child: Opacity(
                          opacity: dock,
                          child: widget.conversation ??
                              _TranscriptText(text: widget.transcript!),
                        ),
                      ),
                    // Status label near the top.
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      child: Opacity(
                        opacity: intro * (1 - dock),
                        child: Text(
                          _label,
                          textAlign: TextAlign.center,
                          style: theme.textStyle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                    // The sky orb.
                    Positioned(
                      left: (w - orb) / 2,
                      top: top,
                      width: orb,
                      height: orb,
                      child: Opacity(
                        opacity: intro,
                        child: RepaintBoundary(
                          child: _Orb(breathe: breathe, react: react),
                        ),
                      ),
                    ),
                    // Live transcript under the centered orb (pre-dock only).
                    if (widget.transcript != null)
                      Positioned(
                        left: 28,
                        right: 28,
                        top: top + orb + 28,
                        child: Opacity(
                          opacity: (intro * (1 - dock * 1.6)).clamp(0, 1),
                          child: Text(
                            widget.transcript!,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textStyle.copyWith(
                              fontSize: 18,
                              height: 1.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Controls (static child, not rebuilt per frame).
                    child!,
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// A luminous nebula sphere: deep space lit by slowly drifting clouds of violet,
/// blue, cyan and magenta, with a bright galactic core, scattered twinkling
/// stars, an outer glow, and rim-shading for depth.
/// A simple, calm sky-blue sphere (ChatGPT-style) — a soft radial gradient with
/// a light top-left highlight and an audio-reactive outer glow.
class _Orb extends StatelessWidget {
  const _Orb({required this.breathe, required this.react});

  /// Breathing value (`0`–`1`).
  final double breathe;

  /// Audio reaction (`0`–`1`).
  final double react;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.15,
          colors: [
            Color(0xFFEAF4FF),
            Color(0xFF8FC3FF),
            Color(0xFF2F7BE6),
            Color(0xFF1657C4),
          ],
          stops: [0.0, 0.4, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B86F0)
                .withValues(alpha: 0.30 + 0.28 * react + 0.08 * breathe),
            blurRadius: 40 + 36 * react,
            spreadRadius: 2 + 6 * react,
          ),
        ],
      ),
    );
  }
}

/// The live transcript shown above the docked orb when there's no conversation
/// to display — bottom-aligned so the latest words sit just over the orb.
class _TranscriptText extends StatelessWidget {
  const _TranscriptText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          reverse: true,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              height: 1.4,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  filled ? Colors.white : Colors.white.withValues(alpha: 0.14),
            ),
            child: Icon(
              icon,
              size: 26,
              color: filled ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

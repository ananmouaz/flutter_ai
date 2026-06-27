import 'dart:math' as math;

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

/// A full-screen, engine-agnostic **Live voice** surface — an animated orb that
/// breathes and reacts to audio [amplitude], a status label, an optional live
/// [transcript], and mute / keyboard / end controls.
///
/// Purely presentational: drive [status] and [amplitude] from your audio engine
/// (realtime STT/TTS) and handle the control callbacks. It fills its parent, so
/// wrap it in a `Scaffold`/`SafeArea` for full-screen use.
class AiLiveSession extends StatefulWidget {
  /// Creates a live session surface.
  const AiLiveSession({
    super.key,
    this.status = AiLiveStatus.listening,
    this.amplitude = 0,
    this.transcript,
    this.muted = false,
    this.onMute,
    this.onKeyboard,
    this.onEnd,
  });

  /// The current phase.
  final AiLiveStatus status;

  /// Normalized audio level (`0`–`1`) driving the orb's reaction.
  final double amplitude;

  /// Live transcript text, if any.
  final String? transcript;

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _breathe.dispose();
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
    final textColor = theme.assistantTextColor;

    return ColoredBox(
      color: const Color(0xFFFAFAFA),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          children: [
            Text(
              _label,
              style: theme.textStyle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.55),
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _breathe,
                  builder: (context, _) => _Orb(
                    breathe: 0.5 - 0.5 * math.cos(2 * math.pi * _breathe.value),
                    amplitude: widget.muted ? 0 : widget.amplitude.clamp(0, 1),
                    active: widget.status == AiLiveStatus.speaking ||
                        widget.status == AiLiveStatus.listening,
                  ),
                ),
              ),
            ),
            if (widget.transcript != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  widget.transcript!,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textStyle.copyWith(
                    fontSize: 18,
                    height: 1.4,
                    color: textColor,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.onKeyboard != null)
                  _CircleButton(
                    icon: Icons.keyboard_outlined,
                    label: 'Keyboard',
                    onTap: widget.onKeyboard,
                    theme: theme,
                  ),
                if (widget.onMute != null)
                  _CircleButton(
                    icon: widget.muted ? Icons.mic_off : Icons.mic_none_rounded,
                    label: widget.muted ? 'Unmute' : 'Mute',
                    onTap: widget.onMute,
                    theme: theme,
                  ),
                if (widget.onEnd != null)
                  _CircleButton(
                    icon: Icons.close,
                    label: 'End',
                    onTap: widget.onEnd,
                    theme: theme,
                    filled: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.breathe,
    required this.amplitude,
    required this.active,
  });

  final double breathe;
  final double amplitude;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const base = 150.0;
    final react = active ? amplitude : amplitude * 0.3;
    final scale = 1 + 0.05 * breathe + 0.22 * react;

    return Container(
      width: base * scale,
      height: base * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // A graded graphite sphere with a soft top-left highlight — dimensional
        // rather than a flat black disc.
        gradient: const RadialGradient(
          center: Alignment(-0.4, -0.45),
          radius: 1.05,
          colors: [
            Color(0xFF8A8A95),
            Color(0xFF45454D),
            Color(0xFF20202A),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B1B20).withValues(alpha: 0.10 + 0.18 * react),
            blurRadius: 30 + 44 * react,
            spreadRadius: 1 + 6 * react,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final AiThemeExtension theme;
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
              color: filled ? theme.accentColor : const Color(0xFFECECEF),
            ),
            child: Icon(
              icon,
              size: 26,
              color: filled ? theme.onAccentColor : theme.assistantTextColor,
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// A full-screen Live voice demo that *simulates* a real-time session: it cycles
/// listening → thinking → speaking with a scripted transcript and a jittery
/// amplitude, so the [AiLiveSession] UI can be felt without a real audio engine.
///
/// When a [controller] is supplied, its conversation is shown behind the orb so
/// the drop-and-shrink dock animation has something to reveal (like ChatGPT).
class LiveDemoScreen extends StatefulWidget {
  /// Creates the live demo screen.
  const LiveDemoScreen({super.key, this.controller});

  /// The chat whose messages are read aloud / shown behind the orb.
  final UseChatController? controller;

  @override
  State<LiveDemoScreen> createState() => _LiveDemoScreenState();
}

class _LiveDemoScreenState extends State<LiveDemoScreen> {
  static const List<(AiLiveStatus, String?, int)> _script = [
    (AiLiveStatus.listening, '"Plan a weekend in Lisbon"', 2800),
    (AiLiveStatus.thinking, null, 1200),
    (
      AiLiveStatus.speaking,
      'Lisbon is a great pick — sunny, about 24°C. Belém and Alfama on day '
          'one, a Sintra day trip on day two.',
      4400,
    ),
    (AiLiveStatus.listening, '"What should I pack?"', 2600),
    (AiLiveStatus.thinking, null, 1100),
    (
      AiLiveStatus.speaking,
      'Light layers and comfy shoes — and a small umbrella, just in case.',
      3600,
    ),
  ];

  final Random _random = Random();
  AiLiveStatus _status = AiLiveStatus.connecting;
  String? _transcript;
  double _amplitude = 0;
  bool _muted = false;
  Timer? _ampTimer;
  Timer? _phaseTimer;

  @override
  void initState() {
    super.initState();
    _ampTimer = Timer.periodic(const Duration(milliseconds: 80), _tickAmp);
    _phaseTimer = Timer(const Duration(milliseconds: 800), () => _advance(0));
  }

  @override
  void dispose() {
    _ampTimer?.cancel();
    _phaseTimer?.cancel();
    super.dispose();
  }

  void _tickAmp(Timer _) {
    final active =
        !_muted &&
        (_status == AiLiveStatus.listening || _status == AiLiveStatus.speaking);
    final target = active ? 0.3 + _random.nextDouble() * 0.6 : 0.04;
    setState(() => _amplitude += (target - _amplitude) * 0.4);
  }

  void _advance(int index) {
    final (status, transcript, durationMs) = _script[index % _script.length];
    setState(() {
      _status = status;
      _transcript = transcript ?? _transcript;
    });
    _phaseTimer = Timer(
      Duration(milliseconds: durationMs),
      () => _advance(index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: AiLiveSession(
        status: _status,
        amplitude: _amplitude,
        transcript: _transcript,
        conversation: _conversation(),
        muted: _muted,
        onMute: () => setState(() => _muted = !_muted),
        onKeyboard: () => Navigator.of(context).pop(),
        onEnd: () => Navigator.of(context).pop(),
      ),
    );
  }

  // The live transcript behind the orb — the real conversation, themed dark and
  // pinned to the bottom so the latest turn sits just above the orb.
  Widget? _conversation() {
    final controller = widget.controller;
    // With no prior chat there's nothing to read — fall back to the transcript.
    if (controller == null || controller.messages.isEmpty) return null;
    return Theme(
      data: Theme.of(context).copyWith(extensions: [AiThemeExtension.dark()]),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => AiConversationView(
          messages: controller.messages,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        ),
      ),
    );
  }
}

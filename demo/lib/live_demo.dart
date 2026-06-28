import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// A full-screen Live voice screen.
///
/// When the platform speech recognizer is available it runs a **real** session:
/// it listens to the mic, streams partial transcripts into [AiLiveSession], and
/// on a final result sends the spoken text to the [controller]. Where the
/// recognizer isn't available (e.g. the iOS simulator, which has no mic) it
/// falls back to a scripted simulation so the UI is still demonstrable.
class LiveDemoScreen extends StatefulWidget {
  /// Creates the live screen.
  const LiveDemoScreen({super.key, this.controller});

  /// The chat the spoken turns are sent to / shown behind the orb.
  final UseChatController? controller;

  @override
  State<LiveDemoScreen> createState() => _LiveDemoScreenState();
}

class _LiveDemoScreenState extends State<LiveDemoScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Random _random = Random();

  AiLiveStatus _status = AiLiveStatus.connecting;
  String? _transcript;
  double _amplitude = 0;
  bool _muted = false;
  bool _real = false;
  bool _disposed = false;

  // Fallback (scripted) simulation timers.
  Timer? _ampTimer;
  Timer? _phaseTimer;

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

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final available = await _speech.initialize(onError: (_) {});
      if (_disposed) return;
      if (available) {
        _real = true;
        await _listen();
        return;
      }
    } on Object {
      // Fall through to the scripted simulation.
    }
    if (!_disposed) _startScript();
  }

  // ---- Real speech recognition ----------------------------------------------

  Future<void> _listen() async {
    if (_disposed || _muted) return;
    setState(() {
      _status = AiLiveStatus.listening;
      _transcript = null;
    });
    await _speech.listen(
      onResult: (result) {
        if (_disposed) return;
        final words = result.recognizedWords;
        setState(() => _transcript = words.isEmpty ? null : '"$words"');
        if (result.finalResult) unawaited(_onFinal(words));
      },
      onSoundLevelChange: (level) {
        if (_disposed) return;
        // Normalize the platform sound level (~-2..10) to 0..1.
        setState(() => _amplitude = ((level + 2) / 12).clamp(0, 1).toDouble());
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onFinal(String text) async {
    if (_disposed) return;
    if (text.trim().isEmpty) {
      await _listen();
      return;
    }
    setState(() => _status = AiLiveStatus.thinking);
    await widget.controller?.sendText(text);
    if (_disposed) return;
    setState(() => _status = AiLiveStatus.speaking);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (_disposed || _muted) return;
    await _listen(); // next turn
  }

  // ---- Fallback scripted simulation -----------------------------------------

  void _startScript() {
    _ampTimer = Timer.periodic(const Duration(milliseconds: 80), _tickAmp);
    _phaseTimer = Timer(const Duration(milliseconds: 800), () => _advance(0));
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

  // ---- Controls --------------------------------------------------------------

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    if (!_real) return;
    if (_muted) {
      await _speech.stop();
    } else {
      await _listen();
    }
  }

  Future<void> _end() async {
    if (_real) await _speech.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _disposed = true;
    _ampTimer?.cancel();
    _phaseTimer?.cancel();
    if (_real) unawaited(_speech.cancel());
    super.dispose();
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
        onMute: () => unawaited(_toggleMute()),
        onKeyboard: () => unawaited(_end()),
        onEnd: () => unawaited(_end()),
      ),
    );
  }

  // The live transcript behind the orb — the real conversation, themed dark.
  Widget? _conversation() {
    final controller = widget.controller;
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

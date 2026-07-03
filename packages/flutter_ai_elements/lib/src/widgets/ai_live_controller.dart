import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_elements/src/widgets/ai_live_session.dart';

/// The audio side of a live voice session: speech-to-text in, text-to-speech
/// out. Implement it over your engine of choice (`speech_to_text` +
/// `flutter_tts`, a realtime API, …); [AiLiveController] drives the rest.
///
/// The package ships no implementation (it has no platform plugins) — a typical
/// `speech_to_text` + `flutter_tts` adapter is ~30 lines.
abstract interface class AiVoiceEngine {
  /// Starts a single listen turn. Report interim transcripts through [onPartial]
  /// (for live display) and optional normalized mic level (`0`–`1`) through
  /// [onLevel]. Call [onDone] with the settled text when the turn ends (silence
  /// timeout or error included); pass an empty string if nothing was recognized.
  Future<void> startListening({
    required void Function(String text) onPartial,
    required void Function(String finalText) onDone,
    void Function(double level)? onLevel,
  });

  /// Stops an in-progress listen turn.
  Future<void> stopListening();

  /// Speaks [text], calling [onDone] when playback finishes or is interrupted.
  Future<void> speak(String text, {required void Function() onDone});

  /// Stops any in-progress speech.
  Future<void> stopSpeaking();

  /// Releases engine resources.
  Future<void> dispose();
}

/// Drives a live-voice loop — **listen → send → speak → re-listen** — by mapping
/// an [AiVoiceEngine] onto a [UseChatController], and exposes the
/// [AiLiveSession] props ([status], [amplitude], [transcript], [muted]) as a
/// [ChangeNotifier].
///
/// This removes the hand-rolled voice state machine from the app: build the UI
/// with `AnimatedBuilder(animation: liveController, ...)` feeding an
/// `AiLiveSession`, and call [start] / [toggleMute] / [stop].
///
/// ```dart
/// final live = AiLiveController(controller: chat, engine: MyVoiceEngine());
/// live.start();
/// // AiLiveSession(status: live.status, amplitude: live.amplitude,
/// //   transcript: live.transcript, muted: live.muted,
/// //   onMute: live.toggleMute, onEnd: live.stop)
/// ```
class AiLiveController extends ChangeNotifier {
  /// Creates a live controller over [controller] and [engine].
  AiLiveController({required this.controller, required this.engine});

  /// The chat controller the voice loop sends to and reads replies from.
  final UseChatController controller;

  /// The audio engine (STT + TTS).
  final AiVoiceEngine engine;

  AiLiveStatus _status = AiLiveStatus.connecting;

  /// The current phase, for [AiLiveSession.status].
  AiLiveStatus get status => _status;

  double _amplitude = 0;

  /// The latest normalized mic level (`0`–`1`), for [AiLiveSession.amplitude].
  double get amplitude => _amplitude;

  String? _transcript;

  /// The in-progress transcript, for [AiLiveSession.transcript].
  String? get transcript => _transcript;

  bool _muted = false;

  /// Whether the mic is muted, for [AiLiveSession.muted].
  bool get muted => _muted;

  bool _running = false;
  // Bumped on every stop()/dispose() so late engine callbacks from a torn-down
  // turn are ignored instead of resurrecting the loop.
  int _generation = 0;

  void _set({AiLiveStatus? status, double? amplitude, String? transcript}) {
    if (_disposed) return;
    if (status != null) _status = status;
    if (amplitude != null) _amplitude = amplitude;
    if (transcript != null) _transcript = transcript;
    notifyListeners();
  }

  /// Starts the session and begins listening.
  void start() {
    if (_running || _disposed) return;
    _running = true;
    _listen();
  }

  void _listen() {
    if (!_running || _muted || _disposed) return;
    final gen = _generation;
    _set(status: AiLiveStatus.listening, transcript: '');
    unawaited(engine.startListening(
      onPartial: (text) {
        if (gen != _generation) return;
        _set(transcript: text);
      },
      onLevel: (level) {
        if (gen != _generation) return;
        _set(amplitude: level.clamp(0, 1).toDouble());
      },
      onDone: (finalText) {
        if (gen != _generation) return;
        unawaited(_onHeard(finalText.trim()));
      },
    ));
  }

  Future<void> _onHeard(String text) async {
    if (!_running || _disposed) return;
    // Nothing recognized — just listen again.
    if (text.isEmpty) {
      _listen();
      return;
    }
    _set(status: AiLiveStatus.thinking, amplitude: 0);
    final gen = _generation;
    try {
      await controller.sendText(text);
    } catch (_) {
      // Surface nothing audibly; drop back to listening.
      if (gen == _generation && _running) _listen();
      return;
    }
    if (gen != _generation || !_running || _disposed) return;
    final reply = controller.conversation.lastMessage;
    final replyText = reply?.role == AiRole.assistant ? reply?.text ?? '' : '';
    if (replyText.trim().isEmpty) {
      _listen();
      return;
    }
    _speak(replyText);
  }

  void _speak(String text) {
    if (!_running || _disposed) return;
    final gen = _generation;
    _set(status: AiLiveStatus.speaking, transcript: null);
    unawaited(engine.speak(
      text,
      onDone: () {
        if (gen != _generation || !_running || _disposed) return;
        _listen();
      },
    ));
  }

  /// Toggles the mic. Muting stops listening/speaking; unmuting re-listens.
  void toggleMute() {
    if (_disposed) return;
    _muted = !_muted;
    if (_muted) {
      _generation++; // ignore any in-flight engine callbacks
      unawaited(engine.stopListening());
      unawaited(engine.stopSpeaking());
      _set(status: AiLiveStatus.listening, amplitude: 0);
    } else if (_running) {
      _listen();
    } else {
      notifyListeners();
    }
  }

  /// Ends the session and releases the engine.
  void stop() {
    if (!_running) {
      _set(status: AiLiveStatus.ended);
      return;
    }
    _running = false;
    _generation++;
    unawaited(engine.stopListening());
    unawaited(engine.stopSpeaking());
    _set(status: AiLiveStatus.ended, amplitude: 0);
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _running = false;
    _generation++;
    unawaited(engine.stopListening());
    unawaited(engine.stopSpeaking());
    unawaited(engine.dispose());
    super.dispose();
  }
}

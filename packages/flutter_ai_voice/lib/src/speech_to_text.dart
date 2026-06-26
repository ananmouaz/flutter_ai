import 'dart:typed_data';

import 'package:flutter_ai_voice/src/transcript.dart';

/// Converts spoken audio into text.
///
/// **Batch transcription is the primary, reliable API.** Native OS speech
/// recognition imposes awkward limits (for example, iOS cuts off after about a
/// minute), so the recommended flow is: record to a buffer or file, then call
/// [transcribeBytes] / [transcribeFile]. Continuous [transcribeStream] is offered
/// for live captions but is best-effort.
///
/// Concrete implementations (on-device Whisper, a cloud service, the platform
/// recognizer) live behind this interface; see `CallbackSpeechToText` for a
/// quick adapter over an existing function.
abstract interface class SpeechToText {
  /// Transcribes a finished audio [audioFile].
  Future<Transcript> transcribeFile(Uri audioFile, {String? language});

  /// Transcribes a finished audio buffer.
  ///
  /// [mediaType] hints at the encoding (for example `audio/wav`).
  Future<Transcript> transcribeBytes(
    Uint8List audio, {
    String? mediaType,
    String? language,
  });

  /// Continuously transcribes a live [audio] stream (experimental, best-effort).
  Stream<TranscriptPartial> transcribeStream(Stream<Uint8List> audio);
}

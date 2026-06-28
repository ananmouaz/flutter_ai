import 'dart:typed_data';

import 'package:flutter_ai_voice/src/speech_to_text.dart';
import 'package:flutter_ai_voice/src/transcript.dart';

/// Transcribes an audio buffer into a [Transcript].
typedef TranscribeBytes = Future<Transcript> Function(
  Uint8List audio, {
  String? mediaType,
  String? language,
});

/// Loads the bytes of an audio file at [file].
typedef AudioFileLoader = Future<Uint8List> Function(Uri file);

/// A [SpeechToText] backed by a plain [TranscribeBytes] function.
///
/// The quickest way to wrap any engine (an on-device Whisper binding, a cloud
/// API, a test stub) without writing a full class. File transcription requires a
/// [AudioFileLoader]; streaming falls back to buffering the whole stream and
/// transcribing once (a reliable batch approximation of live transcription).
class CallbackSpeechToText implements SpeechToText {
  /// Creates an adapter over [transcribe], with an optional [fileLoader].
  const CallbackSpeechToText({
    required TranscribeBytes transcribe,
    AudioFileLoader? fileLoader,
  })  : _transcribe = transcribe,
        _fileLoader = fileLoader;

  final TranscribeBytes _transcribe;
  final AudioFileLoader? _fileLoader;

  @override
  Future<Transcript> transcribeBytes(
    Uint8List audio, {
    String? mediaType,
    String? language,
  }) =>
      _transcribe(audio, mediaType: mediaType, language: language);

  @override
  Future<Transcript> transcribeFile(Uri audioFile, {String? language}) async {
    final loader = _fileLoader;
    if (loader == null) {
      throw UnsupportedError(
        'CallbackSpeechToText has no fileLoader; pass one or use '
        'transcribeBytes.',
      );
    }
    final bytes = await loader(audioFile);
    return _transcribe(bytes, language: language);
  }

  /// Transcribes a stream of audio chunks.
  ///
  /// **WARNING — this is a batch approximation, NOT real streaming.** It buffers
  /// the *entire* [audio] stream in memory and emits **nothing** until the
  /// stream closes, at which point it transcribes the whole buffer in one call
  /// and yields a single final [TranscriptPartial]. There are no incremental
  /// (interim) results.
  ///
  /// Consequences:
  /// - **Unbounded memory**: the full audio is held in RAM, so this is unsuitable
  ///   for long or open-ended live sessions — it will grow without limit.
  /// - **No live feedback**: callers expecting interim transcripts as the user
  ///   speaks will see results only after the stream ends.
  ///
  /// For genuine live transcription, back [SpeechToText] with an engine that
  /// supports streaming directly instead of this callback adapter.
  @override
  Stream<TranscriptPartial> transcribeStream(Stream<Uint8List> audio) async* {
    final buffer = <int>[];
    await for (final chunk in audio) {
      buffer.addAll(chunk);
    }
    final transcript = await _transcribe(Uint8List.fromList(buffer));
    yield TranscriptPartial(text: transcript.text, isFinal: true);
  }
}

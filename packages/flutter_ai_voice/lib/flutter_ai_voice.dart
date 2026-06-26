/// Speech-to-text contracts and models for the `flutter_ai` family.
///
/// `SpeechToText` is the batch-first transcription interface; `Transcript`,
/// `TranscriptSegment`, and `TranscriptPartial` are its data types; and
/// `CallbackSpeechToText` adapts any transcribe function to the interface.
///
/// Concrete engines (on-device Whisper, cloud services, the platform recognizer)
/// implement `SpeechToText` and are intentionally kept out of this package so it
/// stays dependency-free. The typical flow: record audio, transcribe a finished
/// buffer, then feed the text to a chat controller.
library;

export 'src/callback_speech_to_text.dart';
export 'src/speech_to_text.dart';
export 'src/transcript.dart';

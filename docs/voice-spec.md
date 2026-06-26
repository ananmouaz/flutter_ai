# Spec: `flutter_ai_voice`

## Purpose

Optional package for speech-to-text and audio input in AI chat. Batch-first and
reliable; continuous real-time transcription is an experimental extension.

## Target users

- Apps adding voice input ("hold to talk", voice notes) to an AI composer.

## Problems solved

- Reliable transcription despite native OS speech-recognition limits (e.g. iOS
  ~1-minute timeouts) by defaulting to on-device Whisper batch processing.
- A clean bridge from audio → text that drops straight into `UseChatController`.

## Non-goals

- Not in core. Heavy/native deps stay in this leaf package so the base family
  never bloats a bundle.
- No TTS (text-to-speech) in MVP — separate concern, possible future package.
- No always-on wake-word.

## Dependencies

- `flutter_ai_core` (for parts/messages).
- On-device engines: `whisper_kit` (iOS/macOS), `whisper_ggml_plus` (cross-platform
  GGML) for batch transcription.
- Optionally `speech_to_text` for the experimental realtime/OS path.
- Audio capture (e.g. `record`) injected or wrapped.

## Core API

```dart
abstract interface class SpeechToText {
  /// Reliable primary API: transcribe a finished audio file/buffer.
  Future<Transcript> transcribeFile(Uri audioFile, {String? language});
  Future<Transcript> transcribeBytes(Uint8List audio, {String? mediaType, String? language});

  /// Experimental: continuous streaming transcription (best-effort).
  Stream<TranscriptPartial> transcribeStream(Stream<Uint8List> mic);
}

class Transcript { final String text; final List<TranscriptSegment> segments; }
class TranscriptPartial { final String text; final bool isFinal; }

// Implementations
class WhisperKitStt implements SpeechToText { ... }      // iOS/macOS
class WhisperGgmlStt implements SpeechToText { ... }      // cross-platform on-device
class OsSpeechStt implements SpeechToText { ... }         // speech_to_text, experimental realtime
```

## Recommended usage pattern

1. Record to a file/buffer (push-to-talk releases → finish).
2. `transcribeFile(...)` (batch) → reliable text.
3. Feed text into `controller.send(text)`.

Realtime `transcribeStream` is offered for live captions but documented as
best-effort due to OS limits and on-device latency.

## Example

```dart
final stt = WhisperGgmlStt(modelPath: 'ggml-base.en.bin');
final transcript = await stt.transcribeFile(recordedFile);
controller.send(transcript.text);
```

## Extensibility points

- Implement `SpeechToText` for any engine (cloud Whisper, Deepgram, platform).
- Inject audio capture; this package doesn't own the mic.

## MVP vs. future

- **MVP:** batch `transcribeFile` / `transcribeBytes` via Whisper on-device;
  push-to-talk helper widget in `elements` (or here as `AiVoiceButton`).
- **Future:** streaming transcription, language auto-detect, diarization, TTS
  playback for assistant responses.

## Open questions

- Do we bundle a default Whisper model download flow, or leave model provisioning
  to the host? (Lean: host provides model path; we offer a helper.)
- Should `AiVoiceButton` live in `elements` (UI) or here (to keep elements free of
  audio deps)? (Lean: here, depending on core only.)

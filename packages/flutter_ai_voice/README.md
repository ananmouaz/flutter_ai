# flutter_ai_voice

<p align="center"><img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/live_orb.png" width="240" alt="Live voice orb"/></p>

Speech-to-text contracts and models for the [`flutter_ai`](../../README.md)
family. Dependency-free; concrete engines plug in behind the interface.

## Scope — what this package is *not*

This package is **speech-to-text contracts only**. So you know up front, it does
**not** include:

- **No audio capture / recording.** You record the audio (e.g. with `record`,
  `flutter_sound`, or the platform mic) and hand the bytes/file to a
  `SpeechToText`.
- **No text-to-speech (TTS).** Nothing here speaks responses aloud. Wire a TTS
  engine yourself (e.g. `flutter_tts`) and drive the `onSpeak` hook on
  `AiMessageActions`.
- **No bundled STT engine.** `SpeechToText` is an interface — bring on-device
  Whisper, a cloud API, or the platform recognizer.
- **`AiLiveSession` (in `flutter_ai_elements`) is presentational.** The orb,
  transcript, and amplitude reaction are UI; you connect the mic + a
  `SpeechToText` behind it.
- **`transcribeStream` is best-effort, not true live STT.** `CallbackSpeechToText`
  in particular **buffers the whole stream in memory and emits nothing until it
  closes** — see its dartdoc. Prefer the record-then-transcribe flow below.

## Why batch-first

Native OS speech recognition has awkward limits (iOS cuts off after ~1 minute),
so the reliable flow is: **record → transcribe a finished buffer → send the
text**. Continuous `transcribeStream` is offered for live captions but is
best-effort.

## API

- `SpeechToText` — `transcribeBytes`, `transcribeFile`, `transcribeStream`.
- `Transcript` / `TranscriptSegment` / `TranscriptPartial` — result models.
- `CallbackSpeechToText` — wrap any transcribe function without a full class.

## Usage

```dart
import 'package:flutter_ai_voice/flutter_ai_voice.dart';

// Adapt any engine (on-device Whisper, a cloud API, …) in one line:
final stt = CallbackSpeechToText(
  transcribe: (audio, {mediaType, language}) => myWhisper.run(audio),
);

final transcript = await stt.transcribeBytes(recordedBytes);
controller.sendText(transcript.text); // feed into flutter_ai_client
```

## Plugging in a real engine

Implement `SpeechToText` directly, or pass a function to `CallbackSpeechToText`.
On-device options like `whisper_ggml`/`whisper_kit` and cloud services are
intentionally **not** dependencies here, so the package stays light — wire your
chosen engine in the host app or a dedicated adapter package.

## Status

`0.1.1`. Interface + models + callback adapter, fully unit-tested. No concrete
audio engine, recording, or TTS ships in this package (see **Scope** above).

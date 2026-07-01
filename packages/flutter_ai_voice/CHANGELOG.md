# Changelog

## 0.1.4

- Docs: shortened the pubspec `description` into pub.dev's 60–180 character
  window so it renders in full in search results. No code changes.

## 0.1.3

- Docs: refreshed the README listing with a hero image, screenshot gallery,
  and badges (consistent across the package family). No code changes.

## 0.1.2

- Declares supported `platforms:` (all 6) for the pub.dev listing.

## 0.1.1

- Docs: added a clear "Scope — what this package is *not*" section to the README
  (no audio capture, no TTS, no bundled STT engine; `AiLiveSession` is UI-only;
  `transcribeStream` is best-effort/buffered) so the boundaries aren't
  discovered late. No code changes.

## 0.1.0

Initial release.

- `SpeechToText` — batch-first transcription interface (`transcribeBytes`,
  `transcribeFile`, experimental `transcribeStream`).
- `Transcript`, `TranscriptSegment`, `TranscriptPartial` models with JSON.
- `CallbackSpeechToText` — adapts any transcribe function to the interface, with
  a buffering fallback for streaming.
- Dependency-free; concrete engines (Whisper, cloud, platform) plug in behind
  the interface.
- `Transcript` has value equality (`==`/`hashCode`), consistent with its
  segments.

# Changelog

## 0.1.0

Initial release.

- `SpeechToText` — batch-first transcription interface (`transcribeBytes`,
  `transcribeFile`, experimental `transcribeStream`).
- `Transcript`, `TranscriptSegment`, `TranscriptPartial` models with JSON.
- `CallbackSpeechToText` — adapts any transcribe function to the interface, with
  a buffering fallback for streaming.
- Dependency-free; concrete engines (Whisper, cloud, platform) plug in behind
  the interface.

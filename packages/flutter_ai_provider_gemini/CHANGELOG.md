# Changelog

## 0.1.0

Initial release.

- `GeminiProvider` — an `LlmProvider` for the native Gemini API
  (`models/{model}:streamGenerateContent`), with an injectable HTTP client and a
  configurable default model (`gemini-2.5-flash`).
- Supports **Google Search grounding** (`enableGrounding`): grounded answers
  stream their web sources back as `SourcePart` citations.
- Maps conversations to Gemini's wire format: system → `systemInstruction`,
  assistant tool calls → `functionCall`, tool results → `functionResponse`
  (function name recovered from the matching call). Streams text, thinking,
  function calls, citations, and finish reasons as `AiStreamEvent`s.
- `GeminiEventParser` — the chunk→event mapping, unit-tested against recorded SSE.
- Robustness: configurable connect + idle `timeout` (a stalled stream surfaces a
  `StreamErrorEvent` instead of hanging); a wrong-shape chunk emits a
  `StreamErrorEvent` instead of crashing the stream; `close()` only closes a
  client it created; retry backoff is now capped and jittered. When function
  tools and `enableGrounding` are both set, grounding is omitted (the API
  rejects combining them) rather than 400-ing.
- Re-exports `flutter_ai_core`.

> The mapping is unit-tested against recorded SSE chunks; it has not been run
> against the live Gemini API in this release.

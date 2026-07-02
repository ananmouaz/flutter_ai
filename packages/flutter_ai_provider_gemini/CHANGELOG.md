# Changelog

## Unreleased

- Fix: a mid-stream `error` payload is now surfaced as a `StreamErrorEvent`, and
  a blocked prompt (`promptFeedback.blockReason`) finishes as content-filtered —
  instead of both being ignored and rendered as an empty, successful message.
- Fix: tool results delivered across consecutive tool messages (one result per
  message) are no longer dropped — they coalesce into a single `functionResponse`
  turn in call order.
- Fix: `reasoningEffort` now also sets `thinkingConfig.includeThoughts`, so the
  paid thinking is actually surfaced as `ReasoningDelta`s instead of being
  invisible.

## 0.1.11

- Map `AiRequestOptions.reasoningEffort` to `generationConfig.thinkingConfig.
  thinkingBudget`. Requires `flutter_ai_core` ^0.1.13.

## 0.1.10

- Fix (Web): the default HTTP client now streams token-by-token on Flutter Web.
  `http.Client()` resolves to the XHR-backed `BrowserClient` on the web, which
  buffers the entire response body before the stream emits — silently degrading
  streaming to all-at-once. The default is now a `fetch`-based client (via a
  conditional import) that reads the response `ReadableStream` incrementally.
  Native platforms are unchanged. Inject your own `client` to override.

## 0.1.9

- Fix: raise the `flutter_ai_core` lower bound to `^0.1.11` — the parser emits
  `AiUsage` (added in core 0.1.3) and later APIs, so the old `^0.1.0` bound let
  dependency downgrades resolve a core that couldn't compile.
- Docs: shortened the pubspec `description` into pub.dev's 60–180 character
  window.

## 0.1.8

- Docs: refreshed the README listing with a hero image, screenshot gallery,
  and badges (consistent across the package family). No code changes.

## 0.1.7

- Implements `EmbeddingProvider` (`embed` → `batchEmbedContents`, default
  `text-embedding-004`) and `TokenCounter` (`countTokens` → the `countTokens`
  endpoint, reusing the request content mapping).

## 0.1.6

- Tool correlation: `functionResponse` parts are now emitted in the same order
  as their turn's `functionCall`s and keyed by name, so two calls to the same
  tool in one turn line up with their own results (Gemini matches by
  name+position, having no id channel). Synthesized call ids are order-distinct.
- Declares supported `platforms:` (all 6).

## 0.1.5

- Throws typed `LlmException`s (auth/rate-limit/server/request) on HTTP errors
  instead of a generic `Exception`; retries 408/409 too.

## 0.1.4

- A mid-stream stall surfaces a message-scoped `StreamErrorEvent` instead of
  also finalizing (which masked the timeout).
- Asserts a non-empty `apiKey` with an actionable message.

## 0.1.3

- Structured output: maps `AiRequestOptions.responseFormat` to
  `generationConfig.responseSchema` + `responseMimeType: application/json`.

## 0.1.2

- Reports token usage: parses `usageMetadata` (prompt/candidates/total, cached
  content + thoughts tokens) into `AiUsage` on `MessageFinished`.

## 0.1.1

- Docs: added a "Buy me a coffee" (Ko-fi) support section to the README. No code
  changes.

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

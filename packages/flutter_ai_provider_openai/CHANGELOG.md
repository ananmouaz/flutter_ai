# Changelog

## 0.1.2

- Reports token usage: sets `stream_options.include_usage` and parses the
  trailing usage chunk (prompt/completion/total, cached + reasoning token
  details) into `AiUsage` on `MessageFinished`.

## 0.1.1

- Docs: added a "Buy me a coffee" (Ko-fi) support section to the README. No code
  changes.

## 0.1.0

Initial release.

- `OpenAiProvider` — an `LlmProvider` for the OpenAI Chat Completions API (or any
  OpenAI-compatible endpoint via a custom base URL), with an injectable HTTP
  client and a configurable default model.
- Maps conversations (system/user/assistant/tool messages, assistant tool calls,
  tool results) into the request, and streams text, tool calls, and finish
  reasons back as `AiStreamEvent`s.
- `OpenAiChunkParser` — the chunk→event mapping, unit-tested against recorded SSE.
- Robustness: configurable connect + idle `timeout` (a stalled stream surfaces a
  `StreamErrorEvent` instead of hanging); a wrong-shape chunk emits a
  `StreamErrorEvent` instead of crashing the stream; `close()` only closes a
  client it created; retry backoff is now capped and jittered.
- Re-exports `flutter_ai_core`.

> The mapping is unit-tested against recorded SSE chunks; it has not been run
> against the live OpenAI API in this release.

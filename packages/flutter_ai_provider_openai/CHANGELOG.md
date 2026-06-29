# Changelog

## 0.1.6

- Implements `EmbeddingProvider`: `embed(inputs, {model})` POSTs `/embeddings`
  (default `text-embedding-3-small`) and returns `AiEmbedding` vectors.
- Declares supported `platforms:` (all 6).

## 0.1.5

- Throws typed `LlmException`s (auth/rate-limit/server/request) on HTTP errors
  instead of a generic `Exception`; retries 408/409 too.

## 0.1.4

- Readies tool calls on any finish reason (and in `finalize()`), so calls
  can't hang in `inputStreaming`.
- A mid-stream stall now surfaces a message-scoped `StreamErrorEvent` instead of
  also finalizing a terminal event that masked the timeout.
- Asserts a non-empty `apiKey` with an actionable message.

## 0.1.3

- Structured output: maps `AiRequestOptions.responseFormat` to a `json_schema`
  `response_format` (with `strict`).

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

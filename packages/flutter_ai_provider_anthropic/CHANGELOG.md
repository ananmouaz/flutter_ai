# Changelog

## 0.1.5

- Replays signed `thinking` blocks before `tool_use` in the assistant turn, so
  extended thinking + tools no longer 400 on Claude 4.x.
- A mid-stream stall surfaces a message-scoped `StreamErrorEvent` instead of
  also finalizing (which masked the timeout).
- Asserts a non-empty `apiKey` with an actionable message.

## 0.1.4

- Prompt caching: when `AiRequestOptions.cachePrompt` is set, marks the system
  prompt and the last tool with `cache_control: ephemeral` (caches the stable
  prefix for ~90% cheaper repeat input).

## 0.1.3

- Structured output: maps `AiRequestOptions.responseFormat` to a forced tool
  whose input is the schema; its streamed input is surfaced as the JSON answer
  text and the turn finishes as `stop`.

## 0.1.2

- Reports token usage: accumulates input (incl. cache read/creation) from
  `message_start` and output from `message_delta` into `AiUsage` on
  `MessageFinished`.

## 0.1.1

- Docs: added a "Buy me a coffee" (Ko-fi) support section to the README. No code
  changes.

## 0.1.0

Initial release.

- `AnthropicProvider` — an `LlmProvider` for the Anthropic Messages API
  (`POST /v1/messages`), with an injectable HTTP client, a configurable default
  model (`claude-opus-4-8`) and `max_tokens`.
- Maps conversations into the request: system messages fold into the top-level
  `system` field, assistant tool calls become `tool_use` blocks, and tool
  results become `tool_result` blocks. Streams text, extended thinking, tool
  calls, and finish reasons back as `AiStreamEvent`s.
- `AnthropicEventParser` — the SSE-event→event mapping, unit-tested against
  recorded events.
- Robustness: configurable connect + idle `timeout` (a stalled stream surfaces a
  `StreamErrorEvent` instead of hanging); a wrong-shape event emits a
  `StreamErrorEvent` instead of crashing the stream; `close()` only closes a
  client it created; retry backoff is now capped and jittered; adjacent
  same-role turns are merged so the API's strict alternation isn't violated.
- Re-exports `flutter_ai_core`.

> The mapping is unit-tested against recorded SSE events; it has not been run
> against the live Anthropic API in this release.

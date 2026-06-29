# Changelog

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

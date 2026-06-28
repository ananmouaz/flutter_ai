# Changelog

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
- Re-exports `flutter_ai_core`.

> The mapping is unit-tested against recorded SSE events; it has not been run
> against the live Anthropic API in this release.

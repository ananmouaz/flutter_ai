# Changelog

## 0.1.7

- Typed errors: `LlmException` hierarchy (`LlmAuthException`,
  `LlmRateLimitException`, `LlmServerException`, `LlmRequestException`) + a
  `llmExceptionFor` mapper, surfaced on `StreamErrorEvent.error` so hosts can
  branch on the failure type instead of string-matching.

## 0.1.6

- `ReasoningPart` / `ReasoningDelta` gain an optional `signature` (preserved and
  replayed so providers like Anthropic accept thinking blocks on tool rounds).
- `MessageProcessor` keeps the last good partial tool-call args instead of
  clobbering them to `{}` mid-stream.

## 0.1.5

- `AiRequestOptions.cachePrompt`: hint that the stable prompt prefix (system +
  tools) should be cached. Anthropic applies `cache_control`; OpenAI/Gemini cache
  automatically (no-op).

## 0.1.4

- `AiResponseFormat` (+ `AiRequestOptions.responseFormat`): request structured
  output constrained to a JSON schema. Providers route it to their native
  mechanism; the assistant's text is the JSON object.

## 0.1.3

- `AiUsage` model (input/output/cached/reasoning/total tokens) with `+` to
  accumulate and `estimateCost(...)` for cost from per-million prices. Carried on
  `MessageFinished` and stored on the completed `AiMessage`; the processor
  applies it on finish.

## 0.1.2

- Docs: added a "Buy me a coffee" (Ko-fi) support section to the README. No code
  changes.

## 0.1.1

Bug fixes in `MessageProcessor`:
- Zero-argument tool calls (a `ToolCallReady` with no streamed arguments) now
  resolve to empty args + `inputAvailable` instead of being marked errored.
- A `ToolResultReceived` whose `messageId` differs from the call's message (the
  normal case — results arrive in a separate tool-role message) now correctly
  advances the original call to `outputAvailable`.
- A tool-scoped `StreamErrorEvent` (with `toolCallId`) now marks only that call
  errored and lets generation continue, instead of failing the whole message —
  matching `UseChatController`.
- Doc fix: corrected a stale reference to `flutter_markdown_plus`.
- `JsonAccumulator` no longer surfaces an unterminated trailing number/keyword
  (e.g. `1234` from `{"n": 1234`) as a complete value — a literal must be
  delimiter-terminated, preserving the "a partial is always a prefix" contract.
- `MessageProcessor` resolves a tool result to its owning call by scanning the
  conversation when the in-memory map misses (after `reset()`/rehydration).
- `deepHash` uses order-independent hashing for maps (better distribution).

## 0.1.0

Initial release.

- Models: `AiConversation`, `AiMessage`, `AiMessageStatus`, `AiRole`,
  `FinishReason`, and the sealed `AiPart` hierarchy (`TextPart`,
  `ReasoningPart`, `ToolCallPart`, `ToolResultPart`, `FilePart`, `SourcePart`,
  `DataPart`) with manual JSON serialization and value equality.
- Streaming: sealed `AiStreamEvent` set, `MessageProcessor` reducer with granular
  `MutationResult`s, and the tolerant `JsonAccumulator` for partial tool-call
  arguments.
- Contracts: `LlmProvider`, `TextRenderer`, `AiRequestOptions`, `ToolDefinition`.
- Zero runtime dependencies (`dart:core` + `dart:convert` only).

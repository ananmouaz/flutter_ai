# Changelog

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

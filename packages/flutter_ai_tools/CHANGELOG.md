# Changelog

## 0.1.1

- Docs: added a "Buy me a coffee" (Ko-fi) support section to the README. No code
  changes.

## 0.1.0

Initial release.

- `ToolSpec` — a tool declaration (`name`, `description`, JSON-Schema
  `parametersSchema`) plus an optional client-side `execute`; `toDefinition()`
  yields the model-facing `ToolDefinition`.
- `ToolRegistry` — registers tools, exposes their `definitions` for a provider,
  and `run`s a `ToolCallPart` into a `ToolResultPart`, capturing unknown tools
  and thrown executors as error results instead of crashing.
- `WebSearchAdapter` + `webSearchTool` + `SearchResult` — expose any web-search
  backend as a callable tool.
- Pure Dart; re-exports `flutter_ai_core`.

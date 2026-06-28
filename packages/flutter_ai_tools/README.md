# flutter_ai_tools

<p align="center">
  <img src="../../demo/screenshots/element_tool_group.png" width="240" alt="Tool calls"/>
  <img src="../../demo/screenshots/element_confirmation.png" width="240" alt="Confirmation card"/>
</p>

Provider-neutral tool calling for the [`flutter_ai`](../../README.md) family.
Pure Dart, no Flutter dependency.

## What it does

- **`ToolSpec`** — declare a tool (name, description, JSON-Schema parameters) and
  an optional client-side executor.
- **`ToolRegistry`** — collect tools, hand their `definitions` to a provider, and
  `run` a `ToolCallPart` into a `ToolResultPart`. Unknown tools and thrown
  executors become *error results*, never crashes.
- **Web search** — `webSearchTool(adapter)` turns any `WebSearchAdapter`
  (Tavily, Brave, SerpAPI, custom) into a callable tool returning `SearchResult`s.

## Usage

```dart
final tools = ToolRegistry([
  ToolSpec(
    name: 'get_weather',
    description: 'Get the weather for a city',
    parametersSchema: const {
      'type': 'object',
      'properties': {'city': {'type': 'string'}},
      'required': ['city'],
    },
    execute: (args) => weatherApi.fetch(args['city']! as String),
  ),
]);

// Advertise to a provider:
controller.setTools(tools.definitions);

// Fulfill a call the model made:
final result = await tools.run(toolCallPart); // -> ToolResultPart
```

### Web search

```dart
final tools = ToolRegistry([webSearchTool(MyTavilyAdapter())]);
```

```dart
class MyTavilyAdapter implements WebSearchAdapter {
  @override
  Future<List<SearchResult>> search(String query, {int? maxResults}) async {
    // call your search backend, map hits into SearchResult
  }
}
```

## Status

`0.1.0`. Depends on `flutter_ai_core` via a local path (`publish_to: none`) until
it is published. See [`example/`](example/).

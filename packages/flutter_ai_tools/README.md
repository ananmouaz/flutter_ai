<h1 align="center">flutter_ai_tools</h1>

<p align="center"><b>Provider-neutral tool calling for flutter_ai</b> — declare a <code>ToolSpec</code>, register it, and let the agent loop run it. Pure Dart, with a web-search adapter included.</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-tools.png" width="300" alt="Tool calls flowing through the agent loop"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_ai_tools"><img src="https://img.shields.io/pub/v/flutter_ai_tools.svg" alt="flutter_ai_tools on pub.dev"/></a>
  <a href="https://pub.dev/packages/flutter_ai_tools"><img src="https://img.shields.io/pub/points/flutter_ai_tools.svg" alt="pub points"/></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="License: BSD-3-Clause"/></a>
</p>

<p align="center">
  <b>Family:</b> <a href="../../README.md">flutter_ai</a> ·
  <a href="../flutter_ai_core">core</a> · <a href="../flutter_ai_client">client</a> · <a href="../flutter_ai_elements">elements</a> ·
  <a href="../flutter_ai_mcp">mcp</a> · <a href="../flutter_ai_voice">voice</a><br/>
  <a href="../../docs/recipes.md">Recipes</a> · <a href="../../docs/migration-from-vercel-ai-sdk.md">Migrating from the Vercel AI SDK</a>
</p>

---

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

Published on pub.dev (see the CHANGELOG); depends on `flutter_ai_core`.
See [`example/`](example/).

## ☕ Support this project

<p align="center">
  <a href="https://ko-fi.com/ananmouaz"><img src="https://storage.ko-fi.com/cdn/kofi3.png?v=6" alt="Buy me a coffee on Ko-fi" height="72"></a>
</p>

<p align="center"><b>If <code>flutter_ai</code> saves you time, <a href="https://ko-fi.com/ananmouaz">buy me a coffee ☕</a> — it keeps the whole family maintained.</b></p>

<h1 align="center">flutter_ai_core</h1>

<p align="center"><b>The dependency-free Dart engine under flutter_ai</b> — immutable conversation models, a streaming-event reducer, and the <code>LlmProvider</code> contract every provider speaks.</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/hero-streaming.gif" width="300" alt="flutter_ai: a streaming answer with chain-of-thought and a generative-UI task card"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_ai_core"><img src="https://img.shields.io/pub/v/flutter_ai_core.svg" alt="flutter_ai_core on pub.dev"/></a>
  <a href="https://pub.dev/packages/flutter_ai_core"><img src="https://img.shields.io/pub/points/flutter_ai_core.svg" alt="pub points"/></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="License: BSD-3-Clause"/></a>
</p>

<p align="center">
  <b>Family:</b> <a href="../../README.md">flutter_ai</a> ·
  <a href="../flutter_ai_client">client</a> · <a href="../flutter_ai_elements">elements</a> ·
  <a href="../flutter_ai_provider_openai">openai</a> · <a href="../flutter_ai_provider_anthropic">anthropic</a> · <a href="../flutter_ai_provider_gemini">gemini</a> ·
  <a href="../flutter_ai_tools">tools</a> · <a href="../flutter_ai_mcp">mcp</a> · <a href="../flutter_ai_voice">voice</a><br/>
  <a href="../../docs/recipes.md">Recipes</a> · <a href="../../docs/migration-from-vercel-ai-sdk.md">Migrating from the Vercel AI SDK</a>
</p>

<p align="center"><sub>The transcript above is produced by this package's <code>MessageProcessor</code> folding provider events into messages (rendered with <code>flutter_ai_elements</code>).</sub></p>

---

Dependency-free Dart foundation for building AI chat experiences — the shared
contract layer of the [`flutter_ai`](../../README.md) package family.

`flutter_ai_core` has **no runtime dependencies** beyond `dart:core` and
`dart:convert`: no Flutter, no code generation, no `build_runner`. That keeps it
safe to depend on from anywhere and free of version conflicts.

## What's inside

- **Models** — `AiConversation`, `AiMessage`, and the sealed `AiPart` hierarchy
  (`TextPart`, `ReasoningPart`, `ToolCallPart`, `ToolResultPart`, `FilePart`,
  `SourcePart`, `DataPart`). All immutable value types with manual, hand-written
  JSON.
- **Streaming** — the sealed `AiStreamEvent` set and a `MessageProcessor` that
  folds events into conversation state, reporting exactly which messages changed
  so a UI can rebuild only those nodes.
- **Tolerant JSON** — `JsonAccumulator` parses partial tool-call arguments as
  they stream, repairing incomplete JSON without ever throwing.
- **Contracts** — `LlmProvider` (provider abstraction) and `TextRenderer`
  (pluggable text rendering), with `AiRequestOptions` and `ToolDefinition`.

## Design principles

- **Un-opinionated.** No bundled state manager. The processor is a pure,
  synchronous reducer; batching updates to the frame boundary is the consumer's
  job, which keeps this package UI-agnostic and trivially testable.
- **Granular by construction.** `MutationResult.changedMessageIds` lets the UI
  avoid rebuilding the whole transcript on every token.
- **Fails soft.** Malformed streamed tool arguments mark a single call errored
  rather than crashing the stream.

## Example

```dart
import 'package:flutter_ai_core/flutter_ai_core.dart';

void main() {
  final processor = MessageProcessor();

  // Events would normally come from an LlmProvider's stream.
  processor.apply(const MessageStarted(messageId: 'a1', role: AiRole.assistant));
  processor.apply(const TextDelta(messageId: 'a1', delta: 'Hello, '));
  final result = processor.apply(const TextDelta(messageId: 'a1', delta: 'world!'));

  print(result.conversation.messageById('a1')!.text); // Hello, world!
  print(result.changedMessageIds); // {a1}
}
```

See [`example/`](example/) for a fuller walkthrough including tool calls.

## Status

Part of the `flutter_ai` ecosystem; the UI layer (`flutter_ai_elements`) and
provider/controller layer (`flutter_ai_client`) build on these types. See the
CHANGELOG for version history.

## ☕ Support this project

<p align="center">
  <a href="https://ko-fi.com/ananmouaz"><img src="https://storage.ko-fi.com/cdn/kofi3.png?v=6" alt="Buy me a coffee on Ko-fi" height="72"></a>
</p>

<p align="center"><b>If <code>flutter_ai</code> saves you time, <a href="https://ko-fi.com/ananmouaz">buy me a coffee ☕</a> — it keeps the whole family maintained.</b></p>

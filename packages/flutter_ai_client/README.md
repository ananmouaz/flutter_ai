<h1 align="center">flutter_ai_client</h1>

<p align="center"><b>The <code>useChat</code> controller for Flutter</b> — wrap any <code>LlmProvider</code> and get optimistic send, batched streaming, cancel, and regenerate as a plain <code>Listenable</code>. No state-manager lock-in.</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/hero-streaming.gif" width="300" alt="flutter_ai: a streaming answer with chain-of-thought and a generative-UI task card"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_ai_client"><img src="https://img.shields.io/pub/v/flutter_ai_client.svg" alt="flutter_ai_client on pub.dev"/></a>
  <a href="https://pub.dev/packages/flutter_ai_client"><img src="https://img.shields.io/pub/points/flutter_ai_client.svg" alt="pub points"/></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="License: BSD-3-Clause"/></a>
</p>

<p align="center">
  <b>Family:</b> <a href="../../README.md">flutter_ai</a> ·
  <a href="../flutter_ai_core">core</a> · <a href="../flutter_ai_elements">elements</a> ·
  <a href="../flutter_ai_provider_openai">openai</a> · <a href="../flutter_ai_provider_anthropic">anthropic</a> · <a href="../flutter_ai_provider_gemini">gemini</a> ·
  <a href="../flutter_ai_tools">tools</a> · <a href="../flutter_ai_mcp">mcp</a> · <a href="../flutter_ai_voice">voice</a><br/>
  <a href="../../docs/recipes.md">Recipes</a> · <a href="../../docs/migration-from-vercel-ai-sdk.md">Migrating from the Vercel AI SDK</a>
</p>

<p align="center"><sub>The transcript above is driven by this package's <code>UseChatController</code> (rendered with <code>flutter_ai_elements</code>).</sub></p>

---

Provider-agnostic chat controller for the [`flutter_ai`](../../README.md) family.

`UseChatController` wraps any `LlmProvider` (from `flutter_ai_core`) and exposes
conversation state as a plain `Listenable` — so it drops into `ListenableBuilder`
and adapts cleanly to Bloc, Riverpod, or Provider. **It bundles no state-manager
of its own.**

## Features

- **Optimistic send** — the user's message paints synchronously, before the
  request is dispatched.
- **Streaming, batched** — events are folded by `flutter_ai_core`'s
  `MessageProcessor`; notifications are coalesced (injectable scheduler) so high
  token rates don't drop frames.
- **Full control** — `sendText`, `submit`, `stop`, `regenerate`, `clear`.
- **Provider/model switching** — `setProvider`, `setOptions`, `setTools` take
  effect on the next turn without touching the UI.
- **Escape hatch** — a raw `events` stream for custom state layers.

## Usage

```dart
final controller = UseChatController(
  provider: myProvider,                 // any LlmProvider
  options: const AiRequestOptions(model: 'gpt-4o'),
);

// Bind to the UI — rebuilds when the conversation changes.
ListenableBuilder(
  listenable: controller,
  builder: (context, _) => ListView(
    children: [
      for (final m in controller.messages) Text('${m.role.name}: ${m.text}'),
    ],
  ),
);

// Send / stop.
controller.sendText('Hello');
if (controller.status.isBusy) controller.stop();

// Switch model live.
controller.setOptions(const AiRequestOptions(model: 'gpt-4o-mini'));
```

See [`example/`](example/) for a minimal end-to-end widget.

## Implementing a provider

A provider maps your backend's stream onto `flutter_ai_core`'s `AiStreamEvent`s:

```dart
class MyProvider implements LlmProvider {
  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    yield const MessageStarted(messageId: 'a1', role: AiRole.assistant);
    yield const TextDelta(messageId: 'a1', delta: 'Hello!');
    yield const MessageFinished(messageId: 'a1', reason: FinishReason.stop);
  }
}
```

## Status

Published on pub.dev (see the CHANGELOG for versions); depends on `flutter_ai_core`.

_If `flutter_ai` saves you time, you can [buy me a coffee ☕](https://ko-fi.com/ananmouaz)._

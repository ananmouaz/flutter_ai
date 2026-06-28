# flutter_ai_client

<p align="center"><img src="../../demo/screenshots/chat.gif" width="300" alt="Live chat driven by UseChatController"/></p>

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

`0.1.0`. Depends on `flutter_ai_core` via a local path until that package is
published; not itself publishable yet (`publish_to: none`).

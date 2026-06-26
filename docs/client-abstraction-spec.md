# Spec: `flutter_ai_client`

## Purpose

The provider-abstraction and transport layer, plus the `UseChatController` — the
Dart analogue of Vercel's `useChat`. Turns a `LlmProvider` stream into a
`Listenable` the UI can bind to, without imposing a state manager.

## Target users

- App developers wiring a model/backend to the UI.
- Provider-package authors (`flutter_ai_provider_*`) implementing `LlmProvider`.

## Problems solved

- One controller API regardless of provider (OpenAI / Anthropic / Gemini / local /
  custom backend).
- Streaming wired to the frame boundary so the UI stays at 60fps.
- Optimistic send, cancellation (Stop), retry, and error states out of the box.

## Non-goals

- No bundled state manager (no Bloc / Riverpod / GetX). Expose `Listenable` +
  `Stream`; let hosts adapt.
- No provider implementations in this package (those are external/injected).
- No history pruning / token budgeting (server/provider concern).

## Dependencies

- `flutter_ai_core`.
- `package:http` (or an injected `Transport` so hosts can supply Dio/etc.).
- Flutter only for `ChangeNotifier` — or use `package:flutter` foundation;
  controller can also be offered as a pure-Dart `Listenable` if we avoid Flutter.

## Core API

```dart
class UseChatController extends ChangeNotifier {
  UseChatController({ required LlmProvider provider, AiConversation? initial,
    List<ToolSpec> tools = const [], AiRequestOptions? options });

  // State (read-only views)
  AiConversation get conversation;          // full history
  List<AiMessage> get messages;
  ChatStatus get status;                    // idle | submitted | streaming | error
  Object? get error;

  // Actions
  Future<void> send(String text, {List<AiPart> attachments = const []});
  Future<void> submit(AiMessage message);   // lower-level
  void stop();                              // cancels the active stream
  Future<void> regenerate({String? messageId});
  void edit(String messageId, List<AiPart> parts);
  void clear();

  // Provider switching (model/provider abstraction)
  void setProvider(LlmProvider provider);
  void setOptions(AiRequestOptions options); // e.g. model id, temperature

  // Raw stream escape hatch for custom state layers
  Stream<AiStreamEvent> get events;
}

enum ChatStatus { idle, submitted, streaming, error }
```

### Streaming & performance

- The controller consumes `provider.send(...)`, feeds events to a
  `MessageProcessor`, and **batches `notifyListeners()` to the frame boundary**
  (coalesce ticks within a frame; flush via `SchedulerBinding.addPostFrameCallback`
  / `scheduleMicrotask`). One repaint per frame max, regardless of token rate.
- `stop()` cancels the underlying `StreamSubscription` and marks the in-flight
  message `complete` with `finishReason: stop`.
- **Optimistic UI:** `send()` appends the user message and a `pending` assistant
  placeholder *before* the network call returns.

## Provider abstraction

```dart
abstract interface class LlmProvider {          // re-exported from core
  Stream<AiStreamEvent> send(AiConversation c, { List<ToolSpec> tools,
    AiRequestOptions? options });
}

class AiRequestOptions {
  final String? model;
  final double? temperature;
  final int? maxOutputTokens;
  final Map<String, Object?> extra;            // provider-specific passthrough
}
```

Reference providers (separate packages): `flutter_ai_provider_openai`,
`_anthropic`, `_google`, `_local`. Each maps its SDK/HTTP stream into
`AiStreamEvent`s. **Model switching** = swap the provider or change
`options.model`; the UI is untouched.

## Example usage

```dart
final controller = UseChatController(
  provider: OpenAiProvider(apiKey: key),
  options: const AiRequestOptions(model: 'gpt-4o'),
  tools: [weatherTool],
);

ElevatedButton(onPressed: () => controller.send('Hello'), child: Text('Send'));

// Switch model live:
controller.setOptions(const AiRequestOptions(model: 'gpt-4o-mini'));

// Adapt to Riverpod (host side, not in this package):
final chatProvider = ChangeNotifierProvider((_) => controller);
```

## Extensibility points

- `Transport` injection (http/dio/grpc).
- Custom `LlmProvider` for any backend or local model.
- `AiRequestOptions.extra` for provider-specific knobs.
- Subclass / wrap the controller to add persistence, analytics, etc.

## MVP vs. future

- **MVP:** `send`/`stop`/`regenerate`, provider switching, frame-batched
  streaming, optimistic send, error/retry.
- **Future:** automatic tool-call round-tripping (call → execute → resubmit),
  multi-turn agent loops, request queueing, resumable streams.

## Open questions

- Keep the controller Flutter-coupled (via `ChangeNotifier`) or offer a pure-Dart
  `Listenable` to keep `client` Flutter-free? (Lean: ship a pure-Dart `Listenable`
  base, with a thin `ChangeNotifier` adapter.)
- Should automatic tool round-tripping live here or in `flutter_ai_tools`?

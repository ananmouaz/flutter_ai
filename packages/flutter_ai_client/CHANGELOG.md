# Changelog

## 0.1.1

- Persistence seam: a `ChatStore` interface (`load`/`save`) plus an
  `attachStore(controller, store, id)` helper that debounce-auto-saves the
  conversation once each turn settles. History is still in memory by default;
  this makes saving/restoring a thread a few lines. `AiConversation` is already
  JSON-serializable, so a store is just encode/decode around your storage.

## 0.1.0

Initial release.

- `UseChatController` — a `ChangeNotifier` wrapping any `LlmProvider`:
  - optimistic, synchronous user-message append
  - `sendText` / `submit` / `stop` / `regenerate` / `clear`
  - live model/provider switching (`setProvider`, `setOptions`, `setTools`)
  - coalesced, injectable notification scheduling (frame-batched streaming)
  - raw `events` stream escape hatch
- `ChatStatus` (idle / submitted / streaming / error).
- Exposes `stackTrace` alongside `error` so failures can be reported with full
  context.
- A fatal (message-scoped) `StreamErrorEvent` tears down the active turn so a
  misbehaving provider can't keep mutating the conversation after a fatal error;
  tool-scoped errors remain non-fatal.
- Re-exports `flutter_ai_core`.

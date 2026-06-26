# Changelog

## 0.1.0

Initial release.

- `UseChatController` — a `ChangeNotifier` wrapping any `LlmProvider`:
  - optimistic, synchronous user-message append
  - `sendText` / `submit` / `stop` / `regenerate` / `clear`
  - live model/provider switching (`setProvider`, `setOptions`, `setTools`)
  - coalesced, injectable notification scheduling (frame-batched streaming)
  - raw `events` stream escape hatch
- `ChatStatus` (idle / submitted / streaming / error).
- Re-exports `flutter_ai_core`.

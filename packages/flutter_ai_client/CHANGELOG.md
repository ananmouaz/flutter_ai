# Changelog

## 0.2.0

- **BREAKING**: `onToolCalls` now receives a second argument, an
  `AiToolCallSignal`. The controller cancels it when the turn is stopped,
  replaced, or disposed while the executor is still running, so long-running
  tools can abort in-flight work instead of finishing only to have their result
  discarded. Observe it via `signal.isCancelled`, `await signal.whenCancelled`,
  or `signal.throwIfCancelled()`.

  Migration: change `onToolCalls: (calls) async { ... }` to
  `onToolCalls: (calls, signal) async { ... }`. Honoring the signal is optional;
  adding the parameter is required.

## 0.1.8

- Docs: refreshed the README listing with a hero image, screenshot gallery,
  and badges (consistent across the package family). No code changes.

## 0.1.7

- Tool-argument validation (`validateToolArgs`, default on): the agent loop
  validates each model-produced tool call against the tool's
  `parametersSchema` before running it. Calls with invalid args are not
  executed — an error `ToolResultPart` describing the violations is fed back so
  the model can self-correct (bounded by `maxSteps`). Opt out with
  `validateToolArgs: false`.
- History trimming (`trimHistory`): a pluggable strategy that maps the full
  conversation to the (smaller) conversation actually sent to the provider; the
  stored transcript is never trimmed. Ships with `keepLastMessages(n)` and
  `trimToApproxTokenBudget(maxTokens)` strategies (both preserve the system
  prefix and avoid orphaning tool results).

## 0.1.6

- Declare supported platforms (Android/iOS/web/macOS/Windows/Linux) for the
  pub.dev listing.

## 0.1.5

- Turn-sequence guard: a late event from a cancelled stream can no longer mutate
  the conversation or leak onto the `events` stream after a new turn starts.
- `maxBranches` (default 20) caps retained regenerations so a long chat can't
  grow without bound.
- `tokenBudget`: stop the agent loop once cumulative usage exceeds the budget (a
  cost ceiling on top of `maxSteps`).

## 0.1.4

- Thread management: `ChatThread`, a `ChatThreadStore` (list/delete on top of
  `ChatStore`), `autoTitle(conversation)`, and an `InMemoryChatThreadStore` for
  demos/tests — enough to drive a multi-conversation sidebar.

## 0.1.3

- `totalUsage` getter on `UseChatController`: summed `AiUsage` across the
  conversation (feed an `AiContextMeter` or estimate cost).

## 0.1.2

- Agent loop: pass `onToolCalls` (and optional `maxSteps`, default 8) to
  `UseChatController` and it becomes an automatic agent — when a model turn ends
  with unanswered tool calls it runs the executor, feeds the results back, and
  re-prompts until there are no pending calls or `maxSteps` model calls have run.
  Without `onToolCalls` behavior is unchanged (the host drives tools manually via
  `addToolResults`). Cancellation/stop aborts the loop mid-flight.

## 0.1.1

- `editMessage(id, text)` / `editLastUserMessage(text)`: edit a sent user
  message (keeping attachments), discard everything after it, and re-run from
  that point — starting a fresh branch set. Closes the previously dead "edit"
  affordance in `AiMessageActions`.
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

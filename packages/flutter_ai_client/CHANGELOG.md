# Changelog

## Unreleased

- Fix: the controller no longer reports `idle` while the agent loop runs its tool
  executor between model calls. A new `ChatStatus.executingTools` (included in
  `isBusy`) keeps the turn marked busy, so UIs don't re-enable input mid-turn and
  `attachStore` doesn't persist a transcript with unanswered tool calls.
- Fix: `selectBranch` is now a no-op whenever a turn is in flight (including the
  tool-execution phase), preventing a mid-loop branch switch from corrupting the
  transcript.
- Fix: the default message-id generator now uses a per-controller random prefix
  (`msg-<prefix>-<n>`) instead of restarting at `msg-0`, so seeding a controller
  with a rehydrated `ChatStore` transcript no longer produces colliding ids. Pass
  a custom `idGenerator` to override.
- Fix: interrupting a stream with `submit`/`addToolResults`, and an in-band
  `StreamErrorEvent` with no `messageId`, no longer leave the interrupted message
  stuck in the `streaming` state (a permanent typing indicator that also got
  persisted). The trailing message is now finalized.
- Fix: a synchronous throw from `provider.send` or a `trimHistory` callback is
  now caught and surfaced as `ChatStatus.error` (with the turn future
  completing), instead of escaping — which left the status stuck at `submitted`,
  or became an unhandled zone error inside the agent loop.

## 0.2.4

- `keepLastWithSummary`: a context strategy that folds a caller-supplied rolling
  summary of older turns into the request (as a synthetic `system` message)
  instead of silently dropping them — compaction that preserves load-bearing
  context. Your app owns producing/persisting the summary (any model or
  heuristic, saved via `ChatStore`); the strategy just injects it and windows
  the recent messages. No memory service baked in.

## 0.2.3

- Observability: `UseChatController(observer:)` accepts a `ChatObserver` that
  receives the agent lifecycle — turn start, each model request, response with
  token `AiUsage` + finish reason, tool calls/results, errors, and turn end.
  Shaped after the OpenTelemetry GenAI semantic conventions, with no OTel
  dependency — map the callbacks onto your own tracer or analytics sink. Opt-in
  and no-op by default.

## 0.2.2

- Agent guardrail: `maxIdenticalToolCalls` (opt-in, 0 = off) halts the agent
  loop with a typed `AgentLoopException` when the model keeps requesting the
  same tool call (identical name + args) after it has already run that many
  times in a turn — a runaway-loop guard that stops before burning tokens up to
  `maxSteps`. Complements the existing `tokenBudget` token ceiling.

## 0.2.1

- Fix: raise the `flutter_ai_core` lower bound to `^0.1.11` — the controller
  uses `AiUsage` (added in core 0.1.3) and later APIs, so the old `^0.1.0`
  bound let dependency downgrades resolve a core that couldn't compile.
- Docs: shortened the pubspec `description` into pub.dev's 60–180 character
  window.

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

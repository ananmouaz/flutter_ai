# flutter_ai — Full Audit (2026-07-02)

Scope: all 9 packages, demo app, README/docs/screenshots. Baseline: `flutter analyze` clean;
all package test suites pass (each provider skips 1 live-API test). Findings verified against
source by independent reviewers; several engine findings were confirmed by two reviewers
independently.

Severity: **Critical** = guaranteed failure/data loss on a mainline path · **High** = real bug
users will hit · **Medium** = correctness/UX defect in specific flows · **Low** = latent/polish.

---

## 1. Engine — flutter_ai_core + flutter_ai_client

### CRITICAL

**E1. Buffered `TextPart`/`ReasoningPart` aliasing breaks value semantics during streaming.**
`flutter_ai_core/lib/src/streaming/message_processor.dart:295-323`, `models/ai_part.dart:64-79`
Each `TextDelta` appends to a shared `StringBuffer` wrapped by `TextPart.buffered(buffer)`. All
previously returned conversation snapshots alias the same buffer, so old snapshots mutate
retroactively, and `oldConversation == newConversation` is `true` mid-stream. Any consumer that
dedupes by equality — Bloc `Equatable`, Riverpod `select`, `distinct()` — **never sees streaming
updates**, which is exactly the integration path the docs advertise. Fix: freeze the buffer into a
plain `TextPart(buffer.toString())` at part boundaries and on `MessageFinished`; detach old
wrappers before appending. `TextPart.buffered`/`buffer` are also exported public API despite being
documented "internal" (`flutter_ai_core.dart:21`) — hide or mark `@internal`.

**E2. `ChatStatus` drops to `idle` for the whole duration of tool execution.** *(found by two
independent reviewers)* `flutter_ai_client/lib/src/use_chat_controller.dart:541, 569-575, 642`
`_onStreamDone` sets `idle` before `_continueWithTools` runs; `submitted` is restored only after
the executor finishes. Consequences: (a) `isBusy` UIs re-enable send mid-turn; (b) `selectBranch`
(`:332-346`) only guards `streaming/submitted`, so switching branches mid-loop lets the live
continuation append tool results onto the swapped transcript → orphaned tool results → OpenAI/
Anthropic 400 or corrupted context; (c) `attachStore` (`chat_store.dart:59`) persists mid-turn
transcripts with unanswered tool calls. Fix: keep `submitted` (or add `executingTools`) until
`_completeTurn`; make `selectBranch` bail while `_turn != null`.

**E3. Default id generator collides with rehydrated conversations.**
`use_chat_controller.dart:753-756`
`_sequentialIdGenerator` restarts at `msg-0` per controller, but `ChatStore`'s documented flow
seeds `initial: await store.load(id)` containing `msg-0…msg-N`. First new message duplicates an
existing id; `messageById`/`replace`/`editMessage` target the wrong message, widget lists get
duplicate keys. Fix: collision-resistant ids, or seed the counter past max existing `msg-N`.

### HIGH

**E4. `submit()`/`addToolResults` mid-stream leave the interrupted assistant message stuck in
`streaming` status forever.** `use_chat_controller.dart:239-250` vs `:378-388`
`stop()` finalizes with a synthetic `MessageFinished`; `submit()` calls `_stopActiveStream()` and
doesn't — eternal typing indicator, persisted as such by `attachStore`. Fix: reuse `stop()`'s
finalization.

**E5. Synchronous throw from `provider.send(...)` or `trimHistory` is unhandled.**
`use_chat_controller.dart:470-483, :644`
The `LlmProvider` contract permits sync throws. From `submit()` the status sticks at `submitted`
and the turn future never completes; from the agent-loop continuation it becomes an unhandled
zone error. Fix: try/catch in `_dispatch` → route to the `onError` path.

**E6. Message-scoped stream error with `messageId == null` never finalizes the message.**
`use_chat_controller.dart:493-502` + `message_processor.dart:224`
Transcript permanently shows a streaming spinner message. Fix: mirror the `onError` handling by
targeting the last streaming message.

### MEDIUM

- **E7.** `generateObject`/`streamObject` re-throw typed `LlmException`s as
  `FormatException('generateObject failed: $error')`, destroying the type hierarchy and
  `retryAfter`. `flutter_ai_core/lib/src/provider/generate_object.dart:44-45, 106-107`.
- **E8.** `trimToApproxTokenBudget` counts only `TextPart` text — tool args/results/reasoning cost
  0 tokens, so the budget doesn't bound agent-heavy requests at all.
  `flutter_ai_client/lib/src/context_strategy.dart:118`.
- **E9.** Agent loop executes tool calls already in `ToolCallState.error` (filter checks only for
  a `ToolResultPart`), and the processor's tool-scoped error branch misses the
  `_messageIdForToolCall` fallback so errors are dropped after `reset()`.
  `use_chat_controller.dart:654-667`, `message_processor.dart:211-223`.
- **E10.** `attachStore`: `unawaited(store.save(...))` with no error handler → unhandled zone
  error on save failure; detach can silently drop the final state (flush only if `timer.isActive`)
  or flush mid-stream state. `chat_store.dart:54, 66-71`. *(two reviewers)*
- **E11.** `ToolResultPart.copyWith` can't set `result` back to `null` (documented-valid value);
  same broken pattern on `FilePart`/`AiMessage`/`AiRequestOptions` copyWith.
  `ai_part.dart:267-276`. Fix: sentinel-object pattern.

### LOW

- Runaway-guard signature uses `jsonEncode(call.args)` — key-order sensitive; canonicalize.
  `use_chat_controller.dart:651-652`. *(two reviewers)*
- `_lastFinishReason` never reset per step → stale reason to `ChatObserver.onModelResponse`.
  `:151, 488`. *(two reviewers)*
- `onError`-synthesized `StreamErrorEvent` not emitted on the public `events` stream,
  contradicting its docs. `:514-519`.
- `keepLastWithSummary` lacks `keepLastMessages`' early return — can inject a "summary" for
  content that was never summarized; both strategies hoist *all* system messages to the front
  (docs say "leading"). `context_strategy.dart:23-30, 67-84, 122-129`. *(two reviewers)*
- `AiUsage.estimateCost` can go negative if a provider doesn't fold cache tokens into
  `inputTokens`; clamp. `usage.dart:87-92`.
- No `_disposed` guards on `submit`/`sendText` — post-dispose call runs the request unobserved.
- `stop()` records `FinishReason.stop` — indistinguishable from natural stop; consider `aborted`.
- Tool args that are literal `null` become "Invalid tool arguments" instead of empty args.
  `json_accumulator.dart:38-46` + `message_processor.dart:107-148`.
- `InMemoryChatThreadStore.listThreads` comparator non-transitive when `updatedAt` is null.
  `chat_store.dart:139-143`. *(two reviewers)*
- `autoTitle` truncation can split a surrogate pair (emoji). `chat_store.dart:113`.
- `MessageProcessor.apply(MessageStarted)` on existing id returns `_changed` (doc says no-op).
- `validateJsonSchema`: `1.0` should match `"integer"` per spec; `value is int` rejects it.
  `json_schema_validator.dart:154`.
- "Frame-batched streaming" in the client pubspec oversells microtask coalescing.

---

## 2. Providers — openai / anthropic / gemini

Transport fundamentals are solid in all three (stateful UTF-8/line decoding, CRLF, non-200 →
typed `LlmException` with `Retry-After`, keys only in headers, injected clients not closed).

### HIGH

**P1. Anthropic: `reasoningEffort` produces a 400 against the provider's own default model.**
`anthropic_provider.dart:48, 134-135`
Emits `thinking: {type: enabled, budget_tokens: N}`, which is rejected on Claude Opus 4.7/4.8
(adaptive-only) — and the default model is `claude-opus-4-8`. Fix: emit
`thinking: {type: 'adaptive'}` for 4.6+ (optionally map effort to `output_config.effort`), keep
the legacy shape only for older models.

**P2. OpenAI: sends deprecated `max_tokens`; reasoning models (o-series, gpt-5) hard-reject it.**
`openai_provider.dart:86-87`
`reasoningEffort` + `maxOutputTokens` together always 400. Fix: send `max_completion_tokens`.

### MEDIUM

- **P3. Anthropic: mid-stream `error` SSE event masked by a synthetic successful finish** —
  parser doesn't set `_finished`, `finalize()` emits `MessageFinished(stop)`, overwriting the
  error status. An `overloaded_error` renders as a completed message.
  `anthropic_event_parser.dart:170-174` + `anthropic_provider.dart:213-215`.
- **P4. Anthropic: `responseFormat` + `reasoningEffort` → forced `tool_choice` while thinking is
  enabled — guaranteed 400, unguarded.** `anthropic_provider.dart:134-135, 151-152`.
- **P5. Gemini: tool results split across consecutive tool messages are silently dropped**
  (`pendingCalls` cleared after the first tool message; a shape the Anthropic provider explicitly
  supports). `gemini_provider.dart:324-341`.
- **P6. Gemini: thinking budget sent without `includeThoughts: true`** — users pay for thinking
  tokens, reasoning never surfaces; the parser's `ReasoningDelta` branch is dead code.
  `gemini_provider.dart:112-115`.
- **P7. Gemini blocked prompts / mid-stream `{"error":...}` surface as an empty *successful*
  message; OpenAI has the same blind spot for mid-stream error JSON.**
  `gemini_event_parser.dart:41-56`, `openai_chunk_parser.dart:45-63`.

### LOW

- Anthropic: `redacted_thinking` blocks dropped, not replayed (can 400 multi-turn tool use).
- Anthropic: `temperature` forwarded to 4.7/4.8 which reject it unconditionally.
- Gemini: arbitrary HTTPS image URLs mapped to `fileData.fileUri` (Files-API/GCS only) — the same
  `FilePart(url:)` works on OpenAI/Anthropic, 400s on Gemini.
- Gemini: `countTokens` omits systemInstruction and tools — undercounts.
- Shared `http_retry.dart`: `Retry-After` HTTP-date form ignored; `.timeout` doesn't abort the
  underlying request (retry can race the still-open first attempt).
- OpenAI: `stream_options` cannot be omitted (breaks some Azure/compatible endpoints); tool call
  dropped if `id`/`name` arrive in separate fragments; `reasoning_content` (DeepSeek-style)
  discarded; default model `gpt-4o-mini` is dated.
- `close()` not on the `LlmProvider` interface — generic code can't dispose without downcast.
- SSE multi-line `data:` fields not joined per spec (latent for all three APIs today).

Consistency matrix: reasoning visible — Anthropic ✅ / Gemini ❌ (P6) / OpenAI ❌; consecutive
tool-role messages — Anthropic merged / OpenAI OK / Gemini drops (P5); mid-stream provider error —
Anthropic masked (P3) / OpenAI+Gemini invisible (P7); web image URLs — OpenAI+Anthropic OK /
Gemini broken.

---

## 3. UI kit — flutter_ai_elements + demo

### HIGH

**U1. Auto-scroll pin only releases on touch drags — fights mouse-wheel/trackpad scrolling
during streaming.** `ai_chat.dart:252` (release), `:236` (jump)
Wheel/trackpad/keyboard scrolls produce no `dragDetails`, so `_pinned` stays true and every
notification jumps the viewport back while the user scrolls up. Fix: also release on
`UserScrollNotification` opposing the pin / non-self `ScrollUpdateNotification`.

**U2. Demo: dismissing the error banner wipes the entire conversation.**
`demo/lib/main.dart:415` — `onDismiss: controller.clear`. A transient timeout + closing the
banner destroys the transcript with no confirmation. Fix: local dismissed flag; never clear from
a dismiss affordance.

**U3. Composer: attachment-only sends hijacked into voice mode when `onLive` is set.**
`ai_composer.dart:284-301` — `liveWhenEmpty` ignores staged attachments; attach a photo, tap the
main button → full-screen voice session instead of send. Fix: treat
`hasText || attachments.isNotEmpty` as sendable.

### MEDIUM

- **U4.** Message prose not selectable anywhere (only code blocks use `SelectableText`). Wrap
  completed content in `SelectionArea`.
- **U5.** No Shift+Enter newline with hardware keyboards (`textInputAction: send` always
  submits). `ai_composer.dart:201-202`.
- **U6.** Contrast failure: white on amber for caution-tone confirm ≈ 2.2:1 (AA needs 4.5:1);
  fixed `height: 40` buttons clip at large text scale. `ai_confirmation.dart`.
- **U7.** `AiResponse` leaks `TapGestureRecognizer`s on theme changes (rebuild path skips
  `_disposeRecognizers()`). `ai_response.dart:100-124, 400-403`.
- **U8.** Demo transcript bypasses the package's own perf machinery: O(visible × total) results
  map per token, fresh `AiWidgetRegistry` per message build. `demo/lib/main.dart:503, 526-537`.
- **U9.** Streaming shows raw Markdown sigils (`## `, `**`, fences) then visibly pops/reflows on
  settle — the most visible polish gap in the core experience. Render completed blocks through
  Markdown during streaming; animate only the trailing paragraph. `ai_response.dart:419-426`.
- **U10.** Copy actions give zero feedback (no icon swap/snackbar/announce).
  `ai_code_block.dart:75-77`, `ai_message_actions.dart:56-62`.
- **U11.** Sub-44px, gesture-only, semantics-less targets: attachment remove badge (~16px),
  branch arrows (~26px), model selector chip, inline citation, jump/main buttons (36-38px).
- **U12.** Live demo rebuilds the whole screen at ~12.5Hz from amplitude callbacks
  (`live_demo.dart:95-99, 127-137`) — hold amplitude in a `ValueNotifier`.

### LOW

- RTL: three physical-edge usages (loader alignment, blockquote border/padding, "New chat"
  label) in an otherwise directional codebase.
- Hardcoded English bypassing `AiLocalizations` in ~8 widgets (live session, tool invocation,
  chain-of-thought title, context meter, empty state, image/attachment semantics, sources).
- Bubble memo cache never evicted across `clear()`/thread switches.
- `AiCodeBlock` header color hardcoded; long lines can't horizontal-scroll; table scroller has
  no `Scrollbar`.
- Bare `InkWell`s rely on ambient `Material` despite "not hardcoded to Material" claim.
- `AiChat.didUpdateWidget` doesn't resync counters on controller swap.
- No timestamps anywhere in the transcript (no model/theme slot).
- Demo: `MediaQuery.of` over-subscription, 3:1 header contrast, "Keyboard" control just pops the
  route, no recovery if `speech_to_text` stalls without a final result.

**Verified strengths:** frame-coalesced notifications + identity-memoized bubbles + cached
Markdown parse (conversation is *not* rebuilt per token — except in the demo, U8); near-flawless
disposal hygiene; reduce-motion honored everywhere; streaming `ExcludeSemantics` → `liveRegion`
on completion; disciplined theming through `AiThemeExtension`; demo API key via `--dart-define`
only, never persisted.

---

## 4. Supporting packages — tools / mcp / voice

### HIGH

**S1. MCP tool calls have no timeout or cancellation — a hung server stalls the agent turn
forever.** `mcp_tools.dart:26`, `mcp_connection.dart:45`, `tool_spec.dart:7`
`callTool` has no deadline; `mcp_client` 2.0's timeout covers headers only, the SSE body read is
unbounded; `ToolExecutor`'s signature can't receive the `AiToolCallSignal`. Fix: `callTimeout` on
the connection + a cancellation-aware `ToolSpec.execute` overload.

### MEDIUM

- **S2.** `ToolRegistry.run` catches `on Object` — programming `Error`s (bad casts, asserts)
  become model-facing strings; stack traces discarded; internals can leak into model context.
  `tool_registry.dart:51-57`. Fix: rethrow `Error` (or log with stack).
- **S3.** `mcp_client` 2.0.0 dependency risk (verified empirically): unconditional `dart:io`
  import in exported transport, legacy `dart.library.html` conditionals → WASM builds silently
  lose server notifications; a `.backup` file shipped inside `lib/`; int-only request-id
  assumption. Wrapper adds nothing protocol-wise. Consider official `dart_mcp` or vendoring.
  Document "web (JS) OK; WASM: no notifications".
- **S4.** `callTool` drops non-text content (`ImageContent`/`EmbeddedResource`) and joins text
  blocks with no separator. `streamable_http_mcp_connection.dart:61-62`.

### LOW

- MCP tool list is a one-shot snapshot; `tools/list_changed` not observed.
- Connect failures wrapped in generic `StateError`, discarding the typed cause.
- voice: `transcribeFile` passes no `mediaType` hint. `callback_speech_to_text.dart:50-51`.
- tools: `args['query'] as String?` TypeErrors on numeric input → opaque error result.
  `web_search.dart:80`.
- Naming: `flutter_ai_voice` is STT *contracts* only (239 lines, no audio/TTS/permissions) — the
  name promises more; the package is honest about it in docs.

---

## 5. Marketing, docs & screenshots

### Factual errors / won't compile / stale

- **M1. elements README "Rich text" section contradicts the code** — claims the default is
  `PlainTextRenderer`; actually `MarkdownTextRenderer` is default in `AiChat`, `AiMessageBubble`,
  `AiConversationView`. Actively undersells a headline feature. Also stale in
  `ai_text_renderer.dart:8` dartdoc. `flutter_ai_elements/README.md:146-148`.
- **M2. MCP quick-start snippet won't compile** — uses `UseChatController` without the
  `flutter_ai_client` import/dependency. `flutter_ai_mcp/README.md:31-52` (same gap in
  `docs/recipes.md:434`).
- **M3. Demo run instructions wrong/inconsistent** — root README advertises
  `OPENAI/ANTHROPIC_API_KEY` dart-defines that `demo/lib/main.dart:19` never reads (only
  `GEMINI_API_KEY`); `demo/README.md:27-29` says the opposite. Align all three.
- **M4. `docs/overview.md` is a stale pre-release design doc** — lists nonexistent packages,
  omits shipped ones, poses "open questions" settled releases ago. Rewrite or archive.
- **M5.** Vercel migration doc shows the legacy v4 `useChat` shape (`input`/`handleSubmit`) that
  AI SDK v5 removed — your exact target audience will notice.
  `docs/migration-from-vercel-ai-sdk.md:43-47`.

### Screenshots

- **M6. Every `section-*.png` is an uncropped scroll capture bleeding 2-3 unrelated sections**
  — captions don't match pixels in the 3×2 gallery (e.g. "Tools & agents" is mostly Citations +
  Voice). The single most amateurish element of the presentation. Crop to the section card.
- **M7.** All three hero images + GIF show a decapitated "Streaming & Markdown" heading below
  the composer; tool row clipped mid-glyph. Crop to the phone viewport.
- **M8.** `dark_preview.png` is ~70% empty black — recapture with a full transcript.
- Nits: `flutter.dev` cited as a weather source (fake-looking), `running_` status with clipped
  ellipsis, "Your idea here" placeholder checkbox.

### Copy & positioning

- **M9. No positioning against actual pub.dev competitors** (`flutter_gen_ai_chat_ui`,
  `flutter_chat_ui`, `dash_chat_2`, `langchain_dart`, Firebase `flutter_ai_toolkit`) — a
  "How it compares" table would answer the skeptic's first question; ironically
  `docs/competitor-analysis.md` already exists. Pubspec descriptions/topics also lack "chat ui"/
  "chatbot" — what people actually search.
- **M10.** Pitch leans on "the Flutter answer to Vercel AI SDK + AI Elements" — a null reference
  for mobile-only Flutter devs. Lead with self-contained value.
- **M11.** `screenshots:` pubspec field missing from all 9 packages — pub.dev renders up to 5;
  30 ready-made screenshots are sitting in `demo/screenshots/`. Free conversion.
- **M12.** Root quick start shows a 35-line StatefulWidget before the one-liner `AiChatView` —
  invert. Package "Status" sections are filler; replace with trust-building test-coverage facts.
  Ko-fi banner appears 10× (root + all 9 packages) — reads pushy for 0.1.x; once is enough.
- Anthropic README/provider default `claude-opus-4-8`: verify it's a currently served model id.
- MCP README hero alt-text claims the image shows "MCP tools flowing through the agent loop" —
  it doesn't.

**What's genuinely good:** ~40 spot-checked snippets compile against the real API (rare);
CHANGELOGs human-written and explanatory; voice README's "what this is *not*" section is
exemplary; light/dark screenshot parity is pixel-perfect; 143KB hero GIF; the golden-test +
ffmpeg screenshot pipeline is itself a credibility signal; all image URLs resolve.

---

## 6. Top 10 fixes by impact

1. **E1** — freeze streamed text parts; restore value semantics (breaks advertised Bloc/Riverpod usage).
2. **E2** — busy status through tool execution + guard `selectBranch` (transcript corruption).
3. **P1 + P2** — Anthropic thinking shape & OpenAI `max_completion_tokens` (guaranteed 400s on flagship paths).
4. **E3** — id collisions on rehydration (silent data corruption with `ChatStore`).
5. **U1** — release scroll pin on wheel/trackpad (desktop/web streaming is painful now).
6. **U2 + U3** — demo error-dismiss wipes chat; attachment sends hijacked to voice.
7. **M6-M8** — re-crop all hero/section images, recapture dark preview (first impression).
8. **P3 + P7** — surface mid-stream provider errors instead of empty "successful" messages.
9. **S1** — MCP call timeout/cancellation (one hung server wedges the agent loop).
10. **M1-M3** — fix the doc/code mismatches (Markdown default, MCP snippet, demo run instructions) + add "How it compares" and pubspec `screenshots:`.

## 7. Overall verdict

The foundations are genuinely strong — clean immutable models, a careful streaming reducer, a
production-grade UI rendering architecture, disciplined disposal/theming/reduce-motion, honest
docs, and snippets that actually compile. The defects cluster at **cross-feature seams no single
test exercises**: streaming buffers × equality, agent loop × branching × persistence, provider
knobs × current-generation model rules, desktop input × auto-scroll. None require API breaks to
fix except possibly E1. The marketing is above pub.dev average in substance but undermined by
mis-cropped images and a handful of doc/code mismatches at exactly the spots skeptics check
first.

# Mobile agent library review — 2026-10-03

Recommendation: make flutter_ai the easiest way to render **interactive, recoverable agent conversations in Flutter**, with either a hosted agent or an on-device/client-driven agent. Prioritize the interaction seams, a backend transport, and reliable lifecycle handling before expanding the widget count.

This is a research and prioritization document. Proposed APIs and acceptance criteria below are recommendations, not shipped functionality or an implementation commitment.

## Baseline and evidence

- Reviewed local and freshly fetched `origin/main` at `c9b5e0dc10087c216f3d0de11971636ee1399c65`, last committed August 24, 2026, 08:28:54 UTC. The comparison window is August 24–October 3: 40 calendar days. The preceding package release commit was August 21.
- Both Vercel products inspired this repository, as its README states: **AI Elements** is the React component library; **AI SDK** is the model, tool, agent, and streaming infrastructure.
- Inspected package exports, message rendering, controller/tool lifecycle, MCP adapter, voice scope, existing roadmap/audit, and open issues. Historical audit findings were not assumed to remain unfixed.
- Queried official GitHub commits and releases. AI SDK's default-branch history returned 771 commits since the baseline, across the whole monorepo; this is not 771 features. Latest published `ai` release observed: **7.0.127**, October 1. October 2 commits are identified separately below.
- Examined Mobbin image previews for eight screens and three sampled screens of one six-screen flow. Mobbin did not supply capture dates, so these are visual references, not proof of the latest app versions or measured usability improvements. Search results are curated inspiration, not a comprehensive market audit.
- Compared the checked-in `docs/media/hero-streaming.png` with those references. No live app/device audit or performance benchmark was run for this research.

Reproducible upstream queries:

```sh
gh api 'repos/vercel/ai-elements/commits?since=2026-08-24T08:28:54Z&per_page=100' --paginate
gh api 'repos/vercel/ai/commits?since=2026-08-24T08:28:54Z&per_page=100' --paginate
gh api 'repos/vercel/ai-elements/releases?per_page=12'
gh api 'repos/vercel/ai/releases/tags/ai%407.0.127'
```

## What actually changed at Vercel

### AI Elements: no new commits within our inactivity window

The default branch has **no commits after August 24**. Its latest commit is [Question, August 21](https://github.com/vercel/ai-elements/commit/6a9d5b1822ffb10bba4bd97175f01edd7d8651cd): single-select, multi-select, freeform input, and asynchronous submission. It predates our baseline by three days, but is absent from our library and directly relevant. It is on upstream main; the observed latest tagged Elements release, [1.9.0](https://github.com/vercel/ai-elements/releases/tag/ai-elements%401.9.0), is March 12, so do not claim Question is included in that release.

Earlier additions worth evaluating, rather than mislabeling as new:

| Upstream evidence | What it brings | Mobile relevance |
|---|---|---|
| [1.7.0, January 16](https://github.com/vercel/ai-elements/releases/tag/ai-elements%401.7.0) | Voice component collection | Transcript, audio playback and microphone controls are useful; our orb already covers visualization |
| [1.8.0, January 21](https://github.com/vercel/ai-elements/releases/tag/ai-elements%401.8.0) | Agent, terminal, file tree, sandbox, test results and other coding surfaces | Agent identity and output summaries transfer well; an entire IDE kit is a separate audience |
| [1.8.3, February 4](https://github.com/vercel/ai-elements/releases/tag/ai-elements%401.8.3) | Conversation Markdown export, JSX preview, prompt responsiveness fixes | Export is useful; executable JSX has no direct Flutter equivalent and should not drive our architecture |
| [1.9.0, March 12](https://github.com/vercel/ai-elements/releases/tag/ai-elements%401.9.0) | Screenshot input and streaming-preview fixes | Native attachment capture and stable partial rendering matter; browser screen capture does not port directly |

The [current upstream component tree](https://github.com/vercel/ai-elements/tree/6a9d5b1822ffb10bba4bd97175f01edd7d8651cd/packages/elements/src) also contains Plan, Queue, Artifact, Checkpoint, and audio/transcription components. These are inventory gaps, not additions dated to this review window.

### AI SDK: the meaningful recent movement is in agent infrastructure

AI SDK 7 itself [shipped June 25](https://github.com/vercel/ai/releases/tag/ai%407.0.0), before our baseline. Search-indexed documentation can still describe SDK 6; release history and source are the stronger evidence for this dated comparison.

| Date / status | Verified change | What flutter_ai should take from it |
|---|---|---|
| Sept 15; recorded in `ai` 7.0.102 | [Continuous realtime WebSocket sessions](https://github.com/vercel/ai/commit/4b306c26) | Keep realtime in an optional layer; define reconnect, interruption, transcript, audio-buffer and teardown behavior before adding more voice decoration |
| Sept 16; recorded in 7.0.103–104 | [Experimental evaluation API](https://github.com/vercel/ai/commit/123d71f7), [native tool search](https://github.com/vercel/ai/commit/c4e76dee) | Start with deterministic agent regression fixtures; add selective tool discovery only for workloads with enough tools to justify it |
| Sept 23; provider commit | [Anthropic on-demand compaction with signed block round-tripping](https://github.com/vercel/ai/commit/154221fd) | Our local history trimming is not provider-native compaction. Preserve opaque provider metadata if implementing this later |
| Sept 28; recorded in 7.0.120–121 | [Resume active message parts](https://github.com/vercel/ai/commit/e21b98bc), [hydrate partial tool inputs](https://github.com/vercel/ai/commit/c5e90bb1) | Reconnection must preserve part/tool identity and partial state, not restart the prompt or duplicate side effects |
| Sept 30; recorded in 7.0.125 | [Data-part conversion in agent UI helpers](https://github.com/vercel/ai/commit/ff3dcef4) | Treat typed data as a first-class path between agent and UI; first finish our existing registry integration |
| Oct 1; released in [7.0.127](https://github.com/vercel/ai/releases/tag/ai%407.0.127) | Tool-search ranking/limits; cancellation of merged streams on disconnect | Distinguish transport disconnection from user stop; propagate cancellation through owned work |
| Oct 2; main-branch commit, release not established here | [Preserve approval state on resume](https://github.com/vercel/ai/commit/0fe8c674) | Approval is persisted workflow state, not just two buttons |

These lessons are an architectural interpretation of the upstream changes, not a proposal to port the TypeScript SDK wholesale.

## Our coverage and the gaps that matter

| Area | Verified current state | Recommendation |
|---|---|---|
| Conversation basics | 30+ widgets; messages, composer, Markdown/code, reasoning, tools, sources, branching, errors, model selection, context usage | Keep and polish; basic chat-component parity is already strong |
| Interactive generative UI | `AiWidgetRegistry`/`AiDataView` exist, but `AiMessageBubble._content` renders `DataPart` as `_DataChip`; only text has an injected renderer | **First priority:** wire registry and nullable per-part builder through all transcript wrappers; existing [#150](https://github.com/ananmouaz/flutter_ai/issues/150) |
| Values from embedded controls | No standard part-action callback through the transcript; app closures can work around this | Provide an explicit action/address path with no automatic transcript mutation; existing [#151](https://github.com/ananmouaz/flutter_ai/issues/151) |
| Structured questions | Suggestions and binary confirmation exist; no reusable choices-plus-freeform question component | Add `AiQuestion` after the rendering/action seams; support radio, checkbox and freeform modes |
| Approvals | `AiConfirmation` is presentational; `ToolCallState` has no approval states; controller has no persisted approval response API | Add pending/approved/denied/expired semantics and correlated responses in a separately designed engine change |
| Hosted agents | `LlmProvider` can wrap a backend, but no packaged AI SDK UI-message transport exists | Offer an optional HTTP/SSE adapter and an end-to-end server example; explicitly avoid a second local tool loop when the server owns execution |
| Agent loop | Already has max steps, token budget, repeat-call guard, schema validation, tool cancellation signal, observer, history trimming | Build on these. Later add per-step tool selection/options and deadlines when concrete use cases require them |
| Tool cancellation | Controller supplies `AiToolCallSignal`, but `ToolExecutor` takes only arguments and `McpConnection.callTool` has no cancellation parameter | Close this propagation gap before claiming end-to-end cancellation; distinguish ignoring a late result from aborting remote work |
| Resume | Persistence exists, but no packaged in-flight reconnect protocol; [#98](https://github.com/ananmouaz/flutter_ai/issues/98) already tracks it | Start with the backend adapter and explicit session/event identities; stop must never silently reconnect |
| MCP | Streamable HTTP tools, structured results, error handling and call timeout exist; adapter otherwise reduces content to text | Later preserve rich result blocks and expose narrow auth/discovery hooks; do not assume underlying dependency capabilities are publicly exposed |
| Progress and outputs | `AiTask` has pending/active/complete/error items; chain-of-thought, tool groups and widget registry exist | Compose a compact run summary with expand-to-inspect details. Add Plan/Queue/Artifact only where they add behavior beyond these primitives |
| Voice | STT contracts and presentational live-session/orb UI; no bundled recording, TTS or realtime engine | Ship a working record→transcribe→send recipe first; realtime is a separate investment, already [#101](https://github.com/ananmouaz/flutter_ai/issues/101) |

Local evidence: [message bubble](../packages/flutter_ai_elements/lib/src/widgets/ai_message_bubble.dart), [registry](../packages/flutter_ai_elements/lib/src/generative_ui/ai_widget_registry.dart), [controller](../packages/flutter_ai_client/lib/src/use_chat_controller.dart), [tool states](../packages/flutter_ai_core/lib/src/models/tool_call_state.dart), [tool executor](../packages/flutter_ai_tools/lib/src/tool_spec.dart), [MCP transport](../packages/flutter_ai_mcp/lib/src/streamable_http_mcp_connection.dart), [voice scope](../packages/flutter_ai_voice/README.md).

## Mobbin: patterns to adapt

These observations are from the actual returned images. Proposed Flutter behavior is distinguished from what a static screenshot demonstrates.

| Reference | Visible pattern | Proposed adaptation |
|---|---|---|
| [Structured action card](https://mobbin.com/screens/ba8c306d-b55c-4b77-8103-13ef9d9378ce) | Generated task with date/time and Add, Edit, Discard controls; batch acceptance below | Host-defined result card with explicit actions and a settled state after acting. Use the registry/action seam rather than domain-specific task logic in core |
| [Comet assistant](https://mobbin.com/screens/2faad092-c040-40a9-af66-d7426930b2b2) | Assistant sheet, compact “2 steps completed” row, inline source labels, bottom follow-up input | Optional embedded assistant sheet recipe; collapsed run summary; source details on tap |
| [Perplexity answer](https://mobbin.com/screens/fe1aa2bb-e46b-45b2-ac6f-e2cb4916cbf1) | Inline source labels, compact answer actions and source count, full-width follow-up rows | Reuse `AiSources`, citations, actions and suggestions; provide a source-sheet recipe and a vertical suggestions variant |
| [Perplexity follow-up flow](https://mobbin.com/flows/51085b26-5fac-4cd8-a5f0-603d0987bbd9) | Sampled screens show an answer, then a collapsible research checklist with source cards, then related questions | Demonstrate a complete ask→progress→sources→follow-up journey. Do not infer transitions from unsampled screens |
| [Brave Leo](https://mobbin.com/screens/ef660501-a240-4f76-85db-6f70ab8d8b84) | Assistant sheet and categorized prompt-command menu above composer | Consider composer command slots as an extension recipe; not a reason to build a command framework now |
| [Mindvalley starter prompts](https://mobbin.com/screens/1086af93-5300-41b7-8339-90c8aab9d1cc) | Four contextual starter cards above the bottom composer | Add a grid presentation to existing suggestions/empty-state composition; preserve readable wrapping |
| [ChatGPT voice with transcript](https://mobbin.com/screens/75114316-d81d-4e76-aac3-fd3f896e2865) | Transcript remains visible while a small orb and voice/end controls sit near the composer | Keep voice and text in one conversation; make interruption, mute and end states explicit in a future live adapter |

Design judgment: the checked-in demo spends substantial vertical space on branding, model/package controls, context usage, and expanded reasoning before the answer. A production recipe should prioritize the answer, the current task state and the next action; put diagnostic details behind disclosure. Keep the gallery as a gallery, and add a separate minimal production example.

Acceptance for UI work: narrow phone widths, keyboard open, large text, light/dark themes, RTL, reduced motion, accessible labels/focus, and stable scrolling during streaming. Mobbin's iOS references do not establish Android quality; validate both platforms during implementation.

## Proposed implementation sequence

Effort is relative (S/M/L), not a delivery estimate. Each slice should be independently reviewable.

1. **Interactive conversation foundation — M, recommended first.** Complete #150 and #151, then add `AiQuestion`. Preserve default rendering when no builder is supplied. An embedded widget must emit message/part identity plus its value without implicitly mutating history. Demonstrate single choice, multiple choice, freeform, loading, error/retry and answered states through the shipped transcript. Remove the demo's need to fork the bubble. Decide part identity explicitly before changing the public contract.
2. **Hosted-agent connection — L, strategic adoption priority.** Add an optional AI SDK UI-message stream adapter over `LlmProvider`. Pin a supported protocol/version and test recorded streams for text, reasoning, tool input/output, source, data, error, finish and unknown events. Support auth/header injection. Ship a Flutter + Vercel backend example with server-owned tools and credentials. Do not advertise general AI SDK compatibility until fixtures pass.
3. **Persisted approvals and recovery — L, depends on transport/identity design.** Model approval requests/responses and their association with tool calls. Test denial, duplicate responses, process recreation, disconnection, stop, superseded turns and late events. Ensure the server prevents duplicate side effects; a client alone cannot guarantee exactly-once execution. Extend #98 instead of creating a competing reconnect design.
4. **Mobile agent presentation — M.** Compact run summary using existing tasks/tool groups, source-details sheet, full-width follow-ups, starter grid, and actionable result-card recipe. Do not present a task checklist as private model reasoning. Add loading, empty, failed and settled states alongside the happy path.
5. **Targeted engine upgrades — M/L by slice.** Cancellation propagation through tool/MCP execution first; then scoped per-step tools/options, timeout controls, and richer MCP results. Defer native compaction and large-catalog tool search until a concrete app demonstrates the need.
6. **Voice product slice — L for realtime.** First a working capture/transcription recipe and optional playback/TTS contract; then #101 with interruption, reconnection and background/foreground tests. Keep audio dependencies out of core.

Defer desktop IDE components, arbitrary generated code execution, a vector database, and a general multi-agent harness. The differentiator is a reliable native mobile agent experience plus low integration cost, not matching every upstream component name.

## Staying current and earning adoption

- **Weekly:** check upstream release tags and commits since the last reviewed SHA, including Elements even when no new tag exists. Record date, URL, released/main/experimental status, local equivalent, decision and follow-up issue. A recommendation to automate this is not an installed automation.
- **Monthly:** refresh a small Mobbin set for task approvals, question forms, progress, sources and voice. Record capture/version metadata when available; keep canonical Mobbin links and separate observations from design inference.
- **Before each release:** run protocol fixtures, tool/approval lifecycle tests, package checks, and mobile accessibility/scrolling checks. Refresh screenshots from the actual supported example.
- **Adoption assets:** one honest quick-start, a production backend recipe, an interactive agent demo, API documentation discoverable by coding assistants, and a clear compatibility/stability policy. Existing README quick-start versions and roadmap status need reconciliation with package manifests; avoid claiming every older roadmap item is still missing.
- **Measure:** time to first working backend-driven conversation, amount of application glue removed, supported protocol fixture coverage, tool cancellation/recovery correctness, and scrolling performance on a reference device. Establish baselines before setting targets. This research cannot substantiate a market-leadership claim.

## Decision requested

Choose the first implementation slice: **(A)** interactive foundation + `AiQuestion` (recommended), **(B)** hosted-agent adapter, or **(C)** mobile presentation recipes. Approval/recovery and realtime deserve subsequent scoped designs. No library behavior has been changed by this review.

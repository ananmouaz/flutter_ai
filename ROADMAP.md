# flutter_ai roadmap

Where the family is headed on the way to `1.0`. The north star: **the standard,
go-to way to build anything AI-chat in Flutter** — the Flutter answer to Vercel
AI SDK + AI Elements.

This roadmap is the output of a full audit (source-verified) plus market
research against Vercel AI SDK / AI Elements, assistant-ui, CopilotKit / AG-UI,
LangGraph, the MCP spec, provider docs, and the Flutter pub.dev ecosystem
(June 2026). Items are grouped by what makes us *credible* as the standard, what
lets us *win* the Flutter market, and what we deliberately keep out of scope.

> **Status (kept rough — the CHANGELOGs and GitHub issues are the source of
> truth):** Phases 1 and 2 below have **shipped** — the agentic tool loop,
> structured output, token usage + cost, prompt caching, the generative-UI
> registry, thread management, and the MCP client are all published. A
> multi-OS CI matrix and i18n have shipped too. A later expert-panel review
> added a further backlog (correctness, performance, accessibility, DX) tracked
> in issues #40–#68; the correctness/performance/safety/a11y tier of that is
> also shipped.

## Where we stand

Our layered shape — provider-agnostic streaming `core`, a `useChat`-style
`UseChatController`, composable `elements`, a `tools` layer, and a `voice`
contract — already matches the 2026 "standard" template. The Flutter ecosystem
is fragmented into **UI-only** packages (`flutter_chat_ui`, `flutter_gen_ai_chat_ui`,
`dash_chat_2`) and **logic-only** packages (`langchain_dart`, `dartantic_ai`,
`firebase_ai`); none ship the polished-UI + provider-abstraction + controller +
persistence glue in one family. That gap is our wedge.

### Already shipped (keep + market)

- Provider-agnostic streaming (`LlmProvider`) across OpenAI, Anthropic, Gemini
- `UseChatController`: optimistic send, stop, regenerate, **edit**, branch
- Sealed message-part model; 10-event streaming vocabulary; tolerant JSON
  accumulation for partial tool args
- Reasoning surfacing (`ReasoningPart` / `ReasoningDelta`)
- Vision input (`FilePart`), tool definitions + registry, human-in-the-loop
  `AiConfirmation`
- Gemini Google-Search grounding → citations (unique in the field)
- Persistence seam (`ChatStore` + `attachStore`)
- 30+ themed, accessible widgets; pluggable Markdown / code highlighting
- Clean repo: strict lints, zero suppressions/TODOs, per-package examples

## Phase 1 — Credibility (table-stakes we're missing)

These all sit cleanly above the existing `LlmProvider` seam (mostly
`core` / `client` / providers).

1. **Agentic tool loop** — a runner above `LlmProvider` that executes
   tool-call → result → re-prompt until a `stopWhen` / `maxSteps` predicate.
   Today the app must re-call `addToolResults` manually. *(effort: M)*
2. **Structured output** — accept a JSON Schema and route per provider (OpenAI
   `json_schema`+strict, Gemini `response_schema`, Anthropic strict tool-use);
   stream partial objects via the existing accumulator. *(M)*
3. **Token usage + cost accounting** — a `Usage` payload (input/output/cached/
   reasoning tokens) on the terminal stream event + a pluggable price table; and
   honor `Retry-After` in the existing backoff. *(S–M)*
4. **Prompt-caching hooks** — optional per-message cache hints that map to
   Anthropic `cache_control` markers and no-op where caching is automatic
   (OpenAI/Gemini). *(S)*

## Phase 2 — Win the Flutter market (white-space)

Standard on the web, essentially absent in Flutter today.

5. **Generative-UI registry** — a formal name→widget allowlist so typed
   `DataPart`s / tool results render as app widgets (the demo does this ad-hoc;
   make it a first-class, secure registry). *(M)*
6. **Thread / conversation management** — multi-thread store helpers + a
   ChatGPT-style conversation sidebar widget + auto-generated titles. The
   `ChatStore` seam exists; the multi-thread UX does not. Most-requested,
   under-served in Flutter. *(M–L)*
7. **MCP client** — connect to MCP servers (Streamable-HTTP first; stdio is
   desktop-only on mobile) and feed discovered tools into the existing
   `ToolRegistry` so they flow through the agent loop. Dart libs (`dart_mcp`)
   are ready; nobody has wired MCP into a Flutter chat loop yet. *(M)*

## Phase 3 — Polish & trust

- **Observability hooks** — emit lifecycle events shaped like the OpenTelemetry
  GenAI semantic conventions (request/tool/finish + usage); let consumers wire a
  sink. Do **not** hard-depend on an OTel SDK in core.
- **i18n** — UI strings are currently hardcoded ("Send", "Copy", "Stop", …);
  add a localizations delegate (also firms up RTL).
- **CI matrix** — today CI is Linux-only; add web/macOS/Windows and run the demo
  golden tests in CI.
- **Docs site / recipes** — getting-started, advanced recipes, and a "coming
  from Vercel AI SDK" mapping.
- Broaden test coverage in `tools` / `voice`.

## Strongly nice-to-have (round out the family)

- Reasoning **effort/budget** knob (we surface reasoning; we can't yet control
  it) and account for thinking tokens in usage
- **TTS** (voice is STT-only today)
- **Image generation** as a typed capability (Gemini / OpenAI)
- A **provider registry** + string model IDs (we already support
  OpenAI-compatible base URLs → Azure / Ollama; formalize the ergonomics)
- A thin **`embed()`** for embeddings (do not build a vector DB)

## Deliberately out of scope (lazy + correct)

- **Realtime bidirectional voice** (OpenAI Realtime / Gemini Live) — a large,
  separate WebSocket + audio subsystem; defer, or give it its own package.
- **Resumable / persisted in-flight streams** — mostly a backend concern; we'll
  expose a reconnect seam only, not own the server.
- **RAG / vector stores** — stay thin (`embed()` + let MCP / the app supply
  retrieved context); do not build a vector DB into a client toolkit.

These boundaries will be stated in the docs so they aren't a surprise.

---

*Effort tags are rough: S = small, M = medium, L = large. Sequencing favors
closing credibility gaps (Phase 1) before chasing white-space (Phase 2), with
polish (Phase 3) folded in continuously.*

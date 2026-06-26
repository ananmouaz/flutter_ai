# Roadmap

Phased build order. Each phase ships independently usable packages; later phases
depend only "upward" toward `flutter_ai_core`.

## Phase 0 — Foundations (pre-req)

- Monorepo setup (melos), lints (`flutter_lints` / `package:lints`), CI.
- `flutter_ai_core` skeleton: models, parts (sealed), `MessageProcessor` stub,
  `LlmProvider` / `TextRenderer` interfaces. Manual JSON. No deps beyond
  `dart:core` + `dart:convert`.
- **Exit:** `flutter_ai_core` published 0.1, fully tested, zero Flutter dep.

## Phase 1 — UI elements (the visible win)

- `flutter_ai_elements`: `AiConversation`, `AiMessage`, `AiResponse` (markdown via
  `flutter_markdown_plus`), `AiPromptInput` (Send↔Stop), `AiLoader`.
- `AiThemeExtension` + `AiTheme.fallback()` (mobile-first 2026 default).
- Accessibility: strip `Semantics` during streaming, announce on finish.
- A demo app driven by a mock provider (no real network needed).
- **Exit:** a themeable streaming chat UI works against a fake stream at 60fps.

## Phase 2 — Core abstractions & a real provider

- `flutter_ai_client`: `UseChatController` (Listenable), frame-batched streaming,
  optimistic send, stop/regenerate, provider switching.
- One reference provider (`flutter_ai_provider_openai` or `_google`) mapping a
  real SDK/HTTP stream into `AiStreamEvent`s.
- Wire elements ↔ client; demo talks to a real model.
- **Exit:** end-to-end real streaming chat with model switching.

## Phase 3 — Tools & attachments

- `flutter_ai_tools`: `ToolSpec`, lifecycle states, web-search adapter interface,
  optional auto round-tripping.
- Elements: `AiToolInvocation`, `AiToolGroup` (parallel, collapsible),
  `AiSources`, `AiReasoning` / `AiChainOfThought`, attachment previews.
- Tolerant partial-JSON arg parsing + scoped validation errors.
- **Exit:** agent-style chat with visible, inspectable tool calls + attachments.

## Phase 4 — Voice & local AI

- `flutter_ai_voice`: batch Whisper transcription (`whisper_kit` /
  `whisper_ggml_plus`), `AiVoiceButton`, experimental streaming.
- `flutter_ai_provider_local`: on-device inference (llama.cpp FFI) as a leaf
  package — keeps FFI out of core.
- **Exit:** voice input → chat, and a fully offline local-model demo.

## Phase 5 — Ecosystem & integrations

- More reference providers (`_anthropic`, others).
- Generative-UI: strict `Catalog`, `DataPart` binding, example custom widgets.
- Optional extractions *if earned*: `flutter_ai_design_system` (skin presets:
  glass, expressive, cupertino), `flutter_ai_attachments`.
- Interop adapters (e.g. bridge to Google's `flutter_ai_toolkit` provider iface).
- Docs site + `llms.txt` for the family so coding assistants get accurate APIs.
- **Exit:** a published, documented family with multiple providers and skins.

## Sequencing principles

- **UI first** so there's something demoable early (against a mock provider),
  but `core` must exist first as its contract.
- **No heavy deps until the leaf phase** (FFI, native STT) — protects bundle size
  and adoption.
- **Defer splits** (`design_system`, `attachments`) until size/cadence justifies
  them; the seams are already in place (see `package-architecture.md`).

## Cross-cutting definition-of-done (every package)

- No code-gen in `core`; manual JSON where serialization is needed.
- No bundled state manager; `Listenable` + `Stream` only.
- 60fps under streaming (frame-aligned batching, granular mutation).
- Strict catalog, no reflection.
- Tests + example + dartdoc; lints clean.

# Market Demand

## Goals

Establish *why* this ecosystem should exist and who is asking for it, so scope
decisions trace back to real demand rather than feature enthusiasm.

## The signal

- **Vercel AI Elements + AI SDK** set the expectation on web: a maintained,
  composable component library tied to a provider-agnostic SDK. There is no
  equivalent of comparable polish and maintenance in Flutter.
- Flutter developers repeatedly ask, across r/FlutterDev, pub.dev, and GitHub
  issues, for "a chat UI that handles streaming / tool calls / attachments" and
  end up hand-rolling `ListView` + `StreamBuilder` each time.
- Google's own `flutter_ai_toolkit` and the `genui` experiment prove Google sees
  the need, but they are narrow (toolkit) or experimental (genui). There is room
  for a community-grade, provider-neutral, mobile-first family.

## What developers actually want (recurring asks)

1. **Streaming that doesn't jank.** Naive `StreamBuilder`-per-token drops frames.
   This is the single most cited pain point.
2. **Provider neutrality.** "I want to swap OpenAI for a local model / my own
   backend without rewriting the UI."
3. **Tool-call visualization.** Showing what the agent did (args + result),
   ideally collapsible, ideally for parallel calls.
4. **Attachments & images** in the composer and in messages.
5. **A look that feels native on mobile**, not a web component reskinned.
6. **No forced state manager.** Teams already have Bloc/Riverpod and don't want a
   second opinion baked into a UI lib.
7. **Markdown + code blocks + LaTeX/tables** rendered well, with copy buttons.

## Demand vs. supply gaps

| Need | Current Flutter supply | Gap |
|---|---|---|
| Streaming chat UI | DIY, a few unmaintained chat packages | High |
| Provider abstraction | Per-SDK clients, no shared contract | High |
| Tool-call UI | Essentially none | Very high |
| Mobile-first AI design system | None aligned to 2026 patterns | High |
| Voice input for AI | `speech_to_text` (OS limits), whisper bindings | Medium |
| On-device inference | `fllama`, `whisper_ggml` exist but unintegrated | Medium |

## Non-goals (demand we deliberately won't chase)

- A hosted backend or our own model API — we are client-side only.
- Document ingestion / RAG pipelines — delegated to the backend (see
  `tools-and-attachments-spec.md`).
- Token-budget pruning logic — a server/provider concern, not a UI one.

## Open questions

- Is voice demand strong enough to prioritize over tools? (Current roadmap puts
  tools first; voice is Phase 4.)
- How much do users want a batteries-included default skin vs. a bare,
  fully-themed-by-them component set?

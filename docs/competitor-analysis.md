# Competitor & Prior-Art Analysis

## Goals

Map what exists so `flutter_ai` borrows the proven parts and avoids re-solving
solved problems.

## Reference: the web standard

### Vercel AI Elements (`elements.ai-sdk.dev`)
- **What it is:** a set of composable React/shadcn components for AI chat —
  `Conversation`, `Message`, `PromptInput`, `Reasoning`, `ChainOfThought`,
  `Tool`, `Sources`, `Attachment`, `Actions`, `Loader`.
- **Borrow:** the component taxonomy, the streaming-state model, the Send↔Stop
  affordance, per-message actions, reasoning/tool disclosure patterns.
- **Don't borrow:** the shadcn visual language (web/desktop-rooted).
- **LLM-friendly docs:** `ai-sdk.dev/llms.txt` — feed to coding assistants.

### Vercel AI SDK (`ai-sdk.dev`)
- **What it is:** provider-agnostic TS SDK — `streamText`, `generateText`,
  `useChat`, tool calling, structured output, attachments.
- **Borrow:** the provider-abstraction shape, the `useChat`-style controller
  ergonomics (mapped to a Dart `Listenable` controller, not React hooks), the
  message-parts model (text / tool-call / tool-result / reasoning / file).

## Flutter / Dart prior art

| Project | What it does | Takeaway for us |
|---|---|---|
| `flutter_ai_toolkit` (Google) | Drop-in `LlmChatView`, provider interface | Good provider-interface idea; UI is monolithic & Material-locked. We go composable + themed. |
| `genui` (Google, experimental) | A2UI streaming, server-driven generative UI via mutators | **Port the mutator/`MessageProcessor` architecture** for granular, jank-free streaming. |
| `dart_openai`, `google_generative_ai`, `anthropic_sdk_dart` | Per-provider clients | Wrap behind one `LlmProvider` contract instead of leaking each SDK's shape. |
| `flutter_chat_ui` (Flyer) | General chat UI (not AI-specific) | Mature theming ideas, but no streaming/tool/reasoning concepts. |
| `flutter_markdown_plus` | Markdown w/ tables, LaTeX (post-Google handover) | Community standard renderer; use behind a `TextRenderer` interface. |
| `shadcn_flutter` | 84+ shadcn components | Reference for *behavior*, not a dependency; web-rooted look. |
| `forui` | Minimal, touch-optimized UI kit (haptics, adaptive context menus) | Strong mobile primitives; optional skin, not a core dependency. |
| `speech_to_text` | OS speech recognition | Usable but OS timeouts (iOS ~1 min) make it unreliable for long input. |
| `whisper_ggml` / `whisper_kit` | On-device Whisper | Batch transcription is the reliable path; basis for `flutter_ai_voice`. |
| `fllama` | llama.cpp FFI | Keep FFI *out of core*; basis for `flutter_ai_provider_local`. |

## Positioning

`flutter_ai` is the only proposal that combines: (1) Elements-grade component
taxonomy, (2) a provider-neutral, state-manager-neutral core, (3) genui-style
streaming performance, and (4) a mobile-first 2026 design system — as a *family*
of small, composable packages rather than one monolith.

## Open questions

- Do we collaborate with / depend on any of Google's packages, or stay fully
  independent to control the API surface? (Lean: independent core, optional
  interop adapters.)
- Should we publish a `flutter_ai_provider_openai` etc. ourselves, or document how
  to wrap existing SDKs? (Lean: ship 1–2 reference providers, document the rest.)

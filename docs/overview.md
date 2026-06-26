# Overview

`flutter_ai` is a family of Flutter/Dart packages for building AI chat and agent
experiences. It is the Flutter answer to **Vercel AI Elements + AI SDK**: a
component layer that follows Elements' proven component vocabulary, sitting on
top of reusable, un-opinionated logic packages.

It is **not** a port of shadcn. We adopt Vercel Elements' *component taxonomy and
streaming behavior*, but render through a mobile-first, 2026-era design system
driven entirely by Flutter `ThemeExtension`. No web aesthetic is inherited.

## Goals

- Give Flutter developers the same "drop in a chat UI in minutes" experience that
  web developers get from Vercel AI Elements.
- Stay **provider-agnostic**: OpenAI, Anthropic, Gemini, local models, or a custom
  backend all plug into the same controller and UI.
- Be **un-opinionated about state management**: expose `Listenable` and raw `Stream`
  primitives so Bloc / Riverpod / Provider / setState users all feel at home.
- Hit **60fps during token streaming** by batching updates to the frame boundary and
  mutating UI nodes granularly instead of rebuilding immutable trees.
- Read like code the Flutter core team would write: minimal dependencies, no
  code-gen in core, composition over inheritance, AOT- and tree-shake-friendly.

## Audience

- Flutter app developers adding an AI assistant, chatbot, or agent UI.
- Teams who want the Vercel-Elements developer experience without leaving Dart.
- Package authors who want a stable core (`flutter_ai_core`) to build providers,
  tools, and skins on top of.

## The package family

| Package | Layer | Purpose |
|---|---|---|
| `flutter_ai_core` | Logic | Message / conversation models, streaming `MessageProcessor`, no Flutter dep |
| `flutter_ai_client` | Logic | Provider abstraction, transport, `UseChatController` (Listenable) |
| `flutter_ai_elements` | UI | Conversation, Message, PromptInput, Reasoning, Tool, Attachment widgets + `AiThemeExtension` |
| `flutter_ai_tools` | Logic | Tool-calling contracts, structured actions, web-search adapters |
| `flutter_ai_voice` | Optional | Speech-to-text, audio input (batch-first, realtime experimental) |
| `flutter_ai_provider_local` | Optional | On-device inference (FFI kept out of core) |
| `flutter_ai_attachments` | Future | Split out of elements only if attachment handling grows large |
| `flutter_ai_design_system` | Future | Extracted skin, only once the default theme earns its own cadence |

See `package-architecture.md` for the dependency graph and the extraction seams.

## Design direction (decided)

Copy Vercel Elements' **component contract and behavior** (`Conversation`,
`Message`, `PromptInput`, `Reasoning`, `ChainOfThought`, `Tool`, `Attachment`,
streaming states, the Send↔Stop swap). Render it through our own
`AiThemeExtension` with a **mobile-first 2026** default: soft pill shapes,
spring motion, ambient (not harsh) shadows, bottom-centric composer, long-press →
bottom-sheet actions, haptics on stream events, optimistic send.

`flutter_ai_elements` ships the theme *contract* plus a default `AiTheme.fallback()`;
all visual constants live behind the extension so a future
`flutter_ai_design_system` is a non-breaking extraction.

## Requirements

- Dart 3.x, Flutter stable.
- `flutter_ai_core` depends only on `dart:core` + `dart:convert` (no `freezed`,
  no `json_serializable`, no Flutter).
- UI packages depend on Flutter and `flutter_markdown_plus` (behind a
  `TextRenderer` interface).
- No `dart:mirrors` / reflection anywhere.

## Open questions

- Final package names — confirm availability on pub.dev before publish.
- Whether `flutter_ai_client` should ship reference providers in-package or as
  separate `flutter_ai_provider_*` packages (current lean: separate).
- License (MIT vs BSD-3 to match Flutter conventions).

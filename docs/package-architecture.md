# Package Architecture

## Goals

Define the package boundaries, the dependency graph, and the rules that keep the
core lean, AOT-safe, and un-opinionated — the way the Flutter team would scope it.

## Dependency graph

```
                 flutter_ai_core         (pure Dart: dart:core + dart:convert only)
                /        |        \
   flutter_ai_client  flutter_ai_tools   (pure Dart; tools may stay Flutter-free)
        |    \              |
        |     \             |
 flutter_ai_elements  ──────┘            (Flutter UI; depends on core + client + tools)
        |
   (future) flutter_ai_design_system     (extracted skin; depends on elements' theme contract)

 Optional, leaf packages (no one depends on them):
   flutter_ai_voice            -> flutter_ai_core (+ Flutter, platform STT/Whisper)
   flutter_ai_provider_local   -> flutter_ai_client (+ FFI: llama.cpp etc.)
   flutter_ai_attachments      -> flutter_ai_core (+ Flutter) [future split]
```

**Rule of thumb:** dependencies point *up* toward `flutter_ai_core`. Nothing in
core knows about Flutter, providers, FFI, or UI.

## Package rules

### `flutter_ai_core` (the contract layer)
- **Only** `dart:core` and `dart:convert`. No Flutter. No `freezed`,
  `json_serializable`, `equatable`, or any build_runner dependency.
- Manual `fromJson` / `toJson`. Immutable value types with `copyWith`,
  hand-written `==`/`hashCode`.
- Houses: message/conversation models, message *parts*, the streaming
  `MessageProcessor` + mutators, the `LlmProvider` and `TextRenderer` interfaces
  (interfaces only — no implementations that pull deps).

### `flutter_ai_client` (transport + controller)
- Depends on core. Pure Dart where possible (uses `package:http` or accepts an
  injected transport).
- Exposes `UseChatController` as a `ChangeNotifier` (a `Listenable`) plus raw
  `Stream`s. **No Bloc / Riverpod / GetX.**
- Reference providers live in separate `flutter_ai_provider_*` packages or are
  injected by the host; the client only knows the `LlmProvider` contract.

### `flutter_ai_elements` (UI)
- Depends on core + client (+ tools for tool widgets).
- Built from **base Flutter widgets** (`Container`, `AnimatedContainer`,
  `GestureDetector`, `CustomPaint`) — no `shadcn_flutter` / `forui` dependency.
- Styled **only** through `AiThemeExtension`. Ships `AiTheme.fallback()`.
- `flutter_markdown_plus` is the default `TextRenderer`, injectable/replaceable.

### Optional leaf packages
- `flutter_ai_voice`, `flutter_ai_provider_local`, `flutter_ai_attachments`:
  heavy/platform deps (FFI, native STT) live here so installing the core family
  never bloats a bundle.

## Extraction seams (so future splits are non-breaking)

1. **Design system:** all visual constants live under
   `flutter_ai_elements/lib/src/theme/`, behind `AiThemeExtension`. Extracting
   `flutter_ai_design_system` later removes implementations, not the contract.
2. **Attachments:** attachment models live in core; attachment *widgets* live in
   `elements/lib/src/attachments/` as a self-contained subtree, ready to lift out.
3. **Providers:** the `LlmProvider` interface is in core; concrete providers are
   already external, so adding more is additive.

## State & streaming architecture (cross-cutting)

- **Listenable + Stream primitives**, never a bundled state manager.
- **Frame-aligned batching:** the `MessageProcessor` coalesces token/JSON chunks
  and flushes on the scheduler frame boundary (or via `scheduleMicrotask`) so the
  UI repaints at most once per frame, not once per token.
- **Granular mutation:** streaming applies *mutations to individual message-part
  nodes* (genui-style), so only the widget bound to a changed node rebuilds — not
  the whole conversation tree.
- **Strict catalog, no reflection:** generative UI maps validated JSON to a
  developer-registered widget `Catalog`. Unknown/invalid schemas are caught,
  that node halts, and a validation error is emitted to the transport — never a
  crash, never `dart:mirrors`.

## API Sketch (cross-package wiring)

```dart
final provider = OpenAiProvider(apiKey: ...);          // flutter_ai_provider_openai
final controller = UseChatController(provider: provider); // flutter_ai_client

// flutter_ai_elements
AiConversation(
  controller: controller,
  catalog: myWidgetCatalog,        // generative-UI catalog (strict)
  textRenderer: const MarkdownTextRenderer(),
);
```

## Open questions

- Monorepo with `melos`, or independent repos? (Lean: monorepo + melos for dev,
  published independently.)
- Minimum supported Flutter/Dart versions.
- Do `tools` and `voice` ever need to share a "structured action" type from core?

# Changelog

## 0.1.0

Initial release.

- `AiThemeExtension` — a `ThemeExtension` of design tokens (bubble colors,
  shapes, ambient shadow, spacing, typography, motion, haptics) with `copyWith`,
  `lerp`, `of(context)`, and a mobile-first `fallback()`.
- Presentational widgets: `AiMessageBubble` (renders every `AiPart` type;
  streaming-safe semantics), `AiConversationView`, `AiComposer` (Send↔Stop swap,
  haptics), `AiLoader`.
- Controller-bound widgets: `AiChat` (live transcript with auto-scroll and a
  thinking loader) and `AiPromptInput`.
- `AiResponse` — a dependency-free Markdown renderer (headings, bold/italic,
  inline + fenced code, lists, blockquotes, links); `MarkdownTextRenderer` wraps
  it and is now the **default** `AiTextRenderer`. `PlainTextRenderer` remains.
- `AiChainOfThought` (stepwise timeline), `AiTask` (agent checklist),
  `AiInlineCitation` (numbered badge), `AiBranch` (version navigation),
  `AiImage` (loading/error/tap-to-zoom).
- Input upgrades: `AiComposer` gains an attach button, a model-selector slot, a
  voice button, and removable attachment previews; `AiPromptInput` stages
  attachments and switches models via the controller. `AiModelSelector`,
  `AiConfirmation` (approve/deny), `AiContextMeter` (token usage), and
  `AiShimmer` (loading skeleton).
- `AiLiveSession` — a full-screen, engine-agnostic Live voice surface (animated
  orb reacting to amplitude + status, live transcript, mute/keyboard/end). UI
  only; drive it from a realtime audio engine.
- Performance & a11y hardening: `AiResponse` parses Markdown and builds gesture
  recognizers once per text change (not every frame) — important on the
  streaming hot path; `AiLiveSession` animates only the orb (60fps no longer
  rebuilds the conversation); message bubbles no longer subscribe to window
  size in the common bounded case; list items carry stable keys; the composer
  measures with the ambient text scale + direction; disclosure widgets expose
  button/expanded semantics; modal sheets scroll; high-traffic layout uses
  directional insets/alignment for RTL.
- Re-exports `flutter_ai_client` (and `flutter_ai_core`).

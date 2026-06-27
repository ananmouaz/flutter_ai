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
- Re-exports `flutter_ai_client` (and `flutter_ai_core`).

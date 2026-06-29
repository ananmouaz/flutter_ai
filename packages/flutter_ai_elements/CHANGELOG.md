# Changelog

## 0.1.3

- `AiConversationList`: a ChatGPT-style conversation sidebar (New chat + a list
  of `ChatThread`s with select/delete) to pair with a `ChatThreadStore`.

## 0.1.2

- Generative UI: `AiWidgetRegistry` (a `dataType`→widget allowlist) and
  `AiDataView` render `DataPart`s the model emits as your own widgets — no
  reflection, unknown types fall back. The demo wires its chain-of-thought / task
  / confirmation cards through it.

## 0.1.1

- `AiChat` now anchors the message you just sent to the **top** of the viewport
  (ChatGPT-style) and **holds it there** while the answer streams in below,
  reserving just enough trailing space and releasing it as the answer grows.
  A drag releases the pin; a floating "scroll to latest" button appears whenever
  the conversation is scrolled above the bottom.
- New `AiAnimatedResponse`: a **blur fade-in** reveal (the Apple-Intelligence /
  Siri look) so streamed answers appear smoothly — each newly revealed word
  arrives blurred and faded, then sharpens into place over `fadeDuration`
  (`blurSigma` controls the starting blur). Text is paced at a readable
  `charsPerSecond` (default 120) and accelerates to drain a backlog within
  `catchUpWindow` so it never trails far behind a fast stream. Only the few
  words at the leading edge animate at once, so the cost stays bounded. The
  in-flight text renders as plain prose and settles into full Markdown once
  complete. `MarkdownTextRenderer` uses it automatically while streaming.
- `AiMessageActions` is restyled with compact, evenly spaced icon buttons
  (ChatGPT-style) and gains optional `onSpeak`/`onGood`/`onBad`/`onShare`
  actions.
- `AiSources` collapses past `maxVisible` chips (default 6) behind a "+N more"
  toggle, so grounded answers that return dozens of sources no longer flood the
  bubble.
- Pluggable syntax highlighting: `AiCodeBlock`, `AiResponse`, and
  `MarkdownTextRenderer` accept an optional `CodeHighlighter` that turns code +
  language into styled spans. The package ships no grammar engine (stays
  dependency-free); supply one from the app. Defaults to plain monospace.
- Fixed the Markdown block parser hanging (and exhausting memory) when handed a
  partial stream that ended mid-construct, e.g. a lone `#` before its heading
  text arrived — the parser now always makes forward progress.

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

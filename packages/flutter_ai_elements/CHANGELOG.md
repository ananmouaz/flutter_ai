# Changelog

## 0.1.13

- Docs: refreshed the README listing with a hero image, screenshot gallery,
  and badges (consistent across the package family). No code changes.

## 0.1.12

UX polish bundle:

- Skeleton shimmer that crossfades into the first streamed token, and a
  streaming→Markdown crossfade when a turn finishes (both reduced-motion aware).
- Reading-width column: new `AiThemeExtension.maxContentWidth` (default 720)
  centers long answers on wide screens; set to `double.infinity` to disable.
- `AiEmptyState` gains a brand `glyph` and tappable `suggestions`.
- Light haptics on turn completion, confirmation, and chip taps (opt-out via
  `enableHaptics`; no-op on web/desktop).
- Markdown: strikethrough, horizontal rules, and GFM task-list checkboxes;
  link color is now themeable (`AiThemeExtension.linkColor`).
- Source chips: numeric index badge, hover state, and an opt-in favicon
  (`AiSources.showFavicons`, default off — fetching discloses cited hosts to a
  third-party service).
- `AiConfirmation.tone` (`neutral`/`caution`/`danger`) restyles the confirm
  button; `danger` uses the theme error color.
- New `AiOrb` widget and a themeable live-session orb (`AiThemeExtension.orbColor`).

## 0.1.11

- Reduce-motion: `AiLoader` and `AiShimmer` now hold a static state (and stop
  their controllers) when the platform "reduce motion" setting is on, completing
  the accessibility pass across the animated widgets.

## 0.1.10

- `AiAnimatedResponse` shows a blinking caret at the streaming edge (the
  "being written" cue); it holds steady under reduce-motion.

## 0.1.9

- Focus / hover / keyboard on the primary controls (desktop & web): the
  composer's attach/mic and send buttons and the confirmation Allow/Deny buttons
  use Material ink + focus traversal + Enter/Space instead of bare gesture
  detectors. The send/stop/live button now morphs (AnimatedSwitcher) and Stop
  reads as a distinct error-toned affordance.

## 0.1.8

- Semantic theme tokens: `AiThemeExtension` gains `errorColor`, `successColor`,
  `warningColor`, `codeBackgroundColor`, and `codeForegroundColor` (light + dark
  defaults). Previously-hardcoded error/success/warning colors and the code
  block's dark palette now read from the theme, so the family is fully
  rebrandable.

## 0.1.7

- `AiChatView`: a batteries-included drop-in (transcript + composer + layout +
  safe area) so a working chat is a single widget in your `Scaffold` body.

## 0.1.6

- Declare supported platforms (Android/iOS/web/macOS/Windows/Linux) for the
  pub.dev listing; fix a stale library-doc reference (`AiChat`, not the removed
  `AiConversation` widget name).

## 0.1.5

- Performance: `AiConversationView` memoizes bubbles by message identity, so
  only the changing message rebuilds while streaming.
- `AiAnimatedResponse` honors reduce-motion (renders plain text) and isolates
  its reveal in a `RepaintBoundary`.
- `AiLocalizationsScope`: override UI strings with one widget, no delegate
  wiring. Remaining hardcoded strings (reasoning, Allow/Deny, loader/shimmer/
  avatar a11y labels) are now localized.

## 0.1.4

- Internationalization: `AiLocalizations` (+ `AiLocalizationsDelegate`) holds the
  widgets' user-facing strings (defaults English). Every previously-hardcoded
  tooltip/label/action now reads from it, so apps can translate the UI by
  providing a delegate. `AiConversationList.newChatLabel` now defaults to the
  localized value.

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

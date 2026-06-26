# Spec: `flutter_ai_elements`

## Purpose

The UI component layer. Adopts Vercel AI Elements' **component taxonomy and
behavior**, rendered through a **mobile-first, 2026** design system driven by
`AiThemeExtension`. Built from base Flutter widgets — no `shadcn_flutter` / `forui`
dependency.

## Target users

- App developers who want a streaming chat UI that looks native on mobile and is
  fully themeable.

## Problems solved

- A complete, composable chat UI (conversation, message, composer, reasoning,
  tools, attachments) that handles streaming states correctly.
- A look that feels like a 2026 mobile app, not a ported web component.
- Accessibility that survives token streaming.

## Non-goals

- No bundled state manager — binds to a `Listenable` (`UseChatController`).
- No business logic / transport (that's `client`).
- No hardcoded Material or Cupertino visual identity — themed via extension.

## Dependencies

- `flutter`, `flutter_ai_core`, `flutter_ai_client` (+ `flutter_ai_tools` for
  tool widgets).
- `flutter_markdown_plus` (default `TextRenderer`, replaceable).

## Component list (Elements taxonomy)

| Widget | Mirrors Elements | Notes |
|---|---|---|
| `AiConversation` | Conversation | Scrolling thread; auto-stick-to-bottom; binds to controller |
| `AiMessage` | Message | Renders a message's parts; role-aware bubble styling |
| `AiMessageActions` | Actions | Copy / Regenerate / Edit — **long-press → bottom sheet** on mobile |
| `AiPromptInput` | PromptInput | Composer; **Send↔Stop swap**; attachments; bottom-anchored |
| `AiReasoning` | Reasoning | Collapsible chain-of-thought; auto-collapses on finish |
| `AiChainOfThought` | ChainOfThought | Stepwise reasoning timeline |
| `AiToolInvocation` | Tool | One collapsible card per tool call (args + result) |
| `AiToolGroup` | — | **Vertically stacked** collapsible list for *parallel* tool calls |
| `AiSources` | Sources | Citation chips/links from `SourcePart` |
| `AiAttachment` / `AiAttachmentPreview` | Attachment | Image/file/audio previews in composer & messages |
| `AiLoader` | Loader | Thinking/typing indicator (pulsing, spring motion) |
| `AiResponse` | Response | Markdown/code/LaTeX block via `TextRenderer`, with copy buttons |

## Theming: `AiThemeExtension`

```dart
@immutable
class AiThemeExtension extends ThemeExtension<AiThemeExtension> {
  // Surfaces & bubbles
  final Color userBubbleColor, assistantBubbleColor, surface, surfaceVariant;
  final BorderRadiusGeometry bubbleRadius;        // soft pill shapes
  final List<BoxShadow> ambientShadow;            // ambient occlusion, not harsh drops
  // Typography
  final TextStyle bodyText, codeText, headingText; // editorial serif headers optional
  // Spacing & motion
  final EdgeInsets bubblePadding, composerPadding;
  final Duration streamFlushInterval;              // frame-aligned default
  final Curve motionCurve;                         // spring by default
  // Interaction
  final bool enableHaptics;
  // ...copyWith / lerp implemented manually

  static AiThemeExtension fallback();              // the default 2026 mobile skin
}
```

- Components read tokens via `Theme.of(context).extension<AiThemeExtension>()`,
  falling back to `AiThemeExtension.fallback()`.
- Host root uses `MaterialApp` (mature routing/overlays/localization) with the
  extension injected; **no Google look is inherited** because every visual is
  token-driven.
- All visual constants live under `lib/src/theme/` — the extraction seam for a
  future `flutter_ai_design_system`.

## Mobile-first 2026 behaviors (the differentiator)

- **Send↔Stop swap:** composer's primary button becomes a prominent Stop the
  moment `status == streaming`. Non-negotiable on mobile.
- **Optimistic send:** user bubble renders instantly (controller appends before
  network).
- **Long-press → bottom sheet** for per-message actions (vs. web hover).
- **Haptics** bound to stream events: light tick on tool-call complete, distinct
  pulse on stream finish (`enableHaptics`, `HapticFeedback`).
- **Spring motion** for new bubbles, the thinking loader, and the input field
  morphing pill→pulsing-circle while the model thinks.
- **Bottom-centric** composer and primary actions (top of screen is thumb dead-zone).
- **Ambient shadows / soft pill shapes** instead of flat boxes or harsh drops.

## Streaming performance (UI side)

- The conversation listens to `UseChatController` and rebuilds **only the
  message/part nodes** flagged in the latest `MutationResult.changedNodeIds`
  (granular mutation → targeted `setState`/`ValueListenableBuilder`), not the
  whole list.
- Updates are **frame-aligned** (controller batches `notifyListeners`), so high
  token rates never exceed one repaint per frame.

## Accessibility during streaming

- While a text block is actively animating/streaming, its `Semantics` is
  **stripped** (or marked `liveRegion: false`) to avoid flooding VoiceOver/TalkBack.
- On `MessageFinished` (`finishReason` received), the final text is wrapped in a
  semantic node and announced once.
- Tool cards, attachments, and actions carry proper labels and are reachable.

## Example usage

```dart
MaterialApp(
  theme: ThemeData(extensions: [AiThemeExtension.fallback()]),
  home: Scaffold(
    body: AiConversation(
      controller: controller,
      textRenderer: const MarkdownTextRenderer(),     // flutter_markdown_plus
      messageBuilder: (ctx, msg) => AiMessage(message: msg), // overridable
      toolBuilder: (ctx, call) => AiToolInvocation(call: call),
    ),
    bottomNavigationBar: AiPromptInput(
      controller: controller,
      allowAttachments: true,
    ),
  ),
);
```

## Extensibility points

- `messageBuilder`, `toolBuilder`, `attachmentBuilder` overrides on
  `AiConversation`.
- Swap `TextRenderer` (e.g. custom markdown/LaTeX engine).
- Full restyle via `AiThemeExtension` without forking widgets.
- Generative-UI `Catalog`: register custom widgets the model may emit (strict,
  no reflection).

## MVP vs. future

- **MVP:** Conversation, Message, PromptInput (with Stop), Response (markdown),
  Loader, Reasoning, AiToolInvocation, basic Attachment preview, theme + a11y.
- **Future:** AiToolGroup (parallel), ChainOfThought timeline, Sources chips,
  generative-UI catalog widgets, glassmorphism preset skin, advanced motion.

## Open questions

- Default `AiConversation` scroll widget: `ListView` vs. `CustomScrollView` +
  slivers for large histories? (Lean: slivers for perf.)
- Ship `AiTheme.fallback()` as one skin, or also a `glass` and `expressive` preset?
- Do we provide a `CupertinoAiTheme` preset for iOS-flavored apps?

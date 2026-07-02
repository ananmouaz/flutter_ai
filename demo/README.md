# flutter_ai_demo

A showcase app for the [`flutter_ai`](../README.md) package family — a live chat
screen and a gallery of every element, styled with a custom `AiThemeExtension`
(no stock-Material chrome, no ripples).

## Chat in action

A scripted provider streams reasoning → a tool call → the answer → a citation,
with the composer swapping Send for Stop while streaming:

<img src="screenshots/chat.gif" width="300" alt="flutter_ai chat demo" />

## Dark mode

Every element is theme-driven, so dark mode is just `AiThemeExtension.dark()` on
a dark `ThemeData` (toggle it with the header icon):

<img src="screenshots/dark_preview.png" width="300" alt="flutter_ai dark mode" />

## Run it

```bash
flutter run                                       # scripted provider, no key
flutter run --dart-define=GEMINI_API_KEY=your_key # live Gemini (with grounding)
```

With no key the chat uses an in-app scripted provider — **no API key required**.
Passing `GEMINI_API_KEY` switches to the native Gemini provider (with Google
Search grounding). For OpenAI or Anthropic, swap the provider in `lib/main.dart`
(`_buildProvider`) — e.g. `OpenAiProvider(apiKey: ...)` — and pass your key via
`--dart-define`.

## Regenerate the screenshots

Screenshots and the GIF are produced headlessly via a golden-capture test (real
fonts loaded from the SDK), then assembled with ffmpeg:

```bash
flutter test test/capture_test.dart --update-goldens
ffmpeg -y -framerate 8 -i test/shots/chat_%03d.png \
  -vf "scale=380:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse" \
  screenshots/chat.gif
```

A few of these are also mirrored into `packages/flutter_ai_elements/screenshots/`
for the pub.dev listing (referenced by that package's `screenshots:` field); copy
the updated files over after regenerating.

## Elements

| | | |
|:--:|:--:|:--:|
| <img src="screenshots/element_message_user.png" width="220"/><br/>**AiMessageBubble** (user) | <img src="screenshots/element_message_assistant.png" width="220"/><br/>**AiMessageBubble** (rich) | <img src="screenshots/element_tool_invocation.png" width="220"/><br/>**AiToolInvocation** |
| <img src="screenshots/element_tool_group.png" width="220"/><br/>**AiToolGroup** | <img src="screenshots/element_reasoning.png" width="220"/><br/>**AiReasoning** | <img src="screenshots/element_sources.png" width="220"/><br/>**AiSources** |
| <img src="screenshots/element_code_block.png" width="220"/><br/>**AiCodeBlock** | <img src="screenshots/element_attachment.png" width="220"/><br/>**AiAttachment** | <img src="screenshots/element_suggestions.png" width="220"/><br/>**AiSuggestions** |
| <img src="screenshots/element_composer_idle.png" width="220"/><br/>**AiComposer** (idle) | <img src="screenshots/element_composer_busy.png" width="220"/><br/>**AiComposer** (streaming) | <img src="screenshots/element_message_actions.png" width="220"/><br/>**AiMessageActions** |
| <img src="screenshots/element_avatars.png" width="220"/><br/>**AiAvatar** | <img src="screenshots/element_loader.png" width="220"/><br/>**AiLoader** | <img src="screenshots/element_error_banner.png" width="220"/><br/>**AiErrorBanner** |
| <img src="screenshots/element_empty_state.png" width="220"/><br/>**AiEmptyState** | <img src="screenshots/element_response.png" width="220"/><br/>**AiResponse** (Markdown) | <img src="screenshots/element_chain_of_thought.png" width="220"/><br/>**AiChainOfThought** |
| <img src="screenshots/element_task.png" width="220"/><br/>**AiTask** | <img src="screenshots/element_inline_citation.png" width="220"/><br/>**AiInlineCitation** | <img src="screenshots/element_branch.png" width="220"/><br/>**AiBranch** |
| <img src="screenshots/element_image.png" width="220"/><br/>**AiImage** | <img src="screenshots/element_model_selector.png" width="220"/><br/>**AiModelSelector** | <img src="screenshots/element_confirmation.png" width="220"/><br/>**AiConfirmation** |
| <img src="screenshots/element_context_meter.png" width="220"/><br/>**AiContextMeter** | <img src="screenshots/element_shimmer.png" width="220"/><br/>**AiShimmer** | <img src="screenshots/element_live_session.png" width="220"/><br/>**AiLiveSession** (voice) |

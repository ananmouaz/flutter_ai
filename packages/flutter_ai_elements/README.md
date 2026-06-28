# flutter_ai_elements

<p align="center"><img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/chat.gif" width="300" alt="flutter_ai chat"/></p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/element_response.png" width="210" alt="Markdown response"/>
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/element_tool_group.png" width="210" alt="Parallel tool calls"/>
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/element_sources.png" width="210" alt="Sources"/>
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/element_reasoning.png" width="210" alt="Reasoning"/>
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/element_chain_of_thought.png" width="210" alt="Chain of thought"/>
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/element_confirmation.png" width="210" alt="Confirmation"/>
</p>

Composable, themeable Flutter UI for AI chat — the UI layer of the
[`flutter_ai`](../../README.md) family.

It adopts the Vercel AI Elements component vocabulary but renders through a
**mobile-first `AiThemeExtension`**, built from base Flutter widgets. No
`shadcn_flutter` / `forui` dependency, no hardcoded Material or Cupertino look —
restyle everything via theme tokens.

## Widgets

**Presentational** (plain data + callbacks; reusable, testable):
- `AiMessageBubble` — renders one message's parts (text, reasoning, tool calls,
  results, files, sources, data), role-aware, with streaming-safe semantics.
- `AiConversationView` — a scrolling list of bubbles, optional thinking loader.
- `AiComposer` — input with a leading attach (`+`) button and a main button that
  is Live while empty, Send once you type, and Stop while streaming; emits haptics.
- `AiLoader` — a pulsing three-dot thinking indicator.

**Controller-bound** (wire to a `UseChatController`):
- `AiChat` — live transcript with auto-scroll and a thinking loader.
- `AiPromptInput` — composer wired to `sendText` / `stop`.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.controller});
  final UseChatController controller; // from flutter_ai_client

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            Expanded(child: AiChat(controller: controller)),
            AiPromptInput(controller: controller),
          ],
        ),
      );
}
```

## Theming

Register an `AiThemeExtension` (or override the default) on your `ThemeData`:

```dart
MaterialApp(
  theme: ThemeData(
    extensions: [
      AiThemeExtension.fallback().copyWith(
        userBubbleColor: const Color(0xFF7C3AED),
        bubbleRadius: const BorderRadius.all(Radius.circular(28)),
        enableHaptics: true,
      ),
    ],
  ),
  home: const ChatScreen(...),
);
```

Widgets read tokens via `AiThemeExtension.of(context)`, falling back to the
mobile-first default when none is registered. All visual constants live behind
this one extension, so a future `flutter_ai_design_system` can extract them
without breaking the API.

## Rich text

Text renders through an injectable `AiTextRenderer` (`TextRenderer<Widget>`); the
default is `PlainTextRenderer`. Provide your own for Markdown, code highlighting,
or LaTeX:

```dart
AiChat(controller: controller, textRenderer: MyMarkdownRenderer());
```

## Status

`0.1.0`. Published on pub.dev; depends on the sibling `flutter_ai` packages.
See [`example/`](example/) for a full app.

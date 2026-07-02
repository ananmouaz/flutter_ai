<h1 align="center">flutter_ai_elements</h1>

<p align="center"><b>The batteries-included AI chat UI kit for Flutter</b> — drop in a polished, streaming chat in one widget, or compose 30+ themeable pieces yourself.</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/hero-streaming.gif" width="300" alt="flutter_ai_elements: a streaming answer with chain-of-thought and a generative-UI task card"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_ai_elements"><img src="https://img.shields.io/pub/v/flutter_ai_elements.svg" alt="flutter_ai_elements on pub.dev"/></a>
  <a href="https://pub.dev/packages/flutter_ai_elements"><img src="https://img.shields.io/pub/points/flutter_ai_elements.svg" alt="pub points"/></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="License: BSD-3-Clause"/></a>
</p>

<p align="center">
  <b>Family:</b> <a href="../../README.md">flutter_ai</a> ·
  <a href="../flutter_ai_core">core</a> · <a href="../flutter_ai_client">client</a> ·
  <a href="../flutter_ai_provider_openai">openai</a> · <a href="../flutter_ai_provider_anthropic">anthropic</a> · <a href="../flutter_ai_provider_gemini">gemini</a> ·
  <a href="../flutter_ai_tools">tools</a> · <a href="../flutter_ai_mcp">mcp</a> · <a href="../flutter_ai_voice">voice</a><br/>
  <a href="../../docs/recipes.md">Recipes</a> · <a href="../../docs/migration-from-vercel-ai-sdk.md">Migrating from the Vercel AI SDK</a>
</p>

---

## Gallery

<table>
  <tr>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-streaming.png" width="220" alt="Streaming response"/><br/>
      <b>Streaming response</b><br/>
      <sub><code>AiChat</code> · <code>AiResponse</code> · <code>AiLoader</code></sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-generative-ui.png" width="220" alt="Generative UI task card"/><br/>
      <b>Generative UI</b><br/>
      <sub><code>AiMessageBubble</code> (custom <code>DataPart</code> renderers)</sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-tools.png" width="220" alt="Tool calls"/><br/>
      <b>Tool calls</b><br/>
      <sub><code>AiToolGroup</code> · <code>AiReasoning</code></sub>
    </td>
  </tr>
  <tr>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-citations.png" width="220" alt="Source citations"/><br/>
      <b>Citations</b><br/>
      <sub><code>AiSources</code> · <code>AiInlineCitation</code></sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-theming.png" width="220" alt="Theming"/><br/>
      <b>Theming</b><br/>
      <sub><code>AiThemeExtension</code> tokens</sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/hero-dark.png" width="220" alt="Dark mode"/><br/>
      <b>Dark mode</b><br/>
      <sub>One theme extension, light &amp; dark</sub>
    </td>
  </tr>
</table>

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
- `AiComposer` — the **presentational** input: a leading attach (`+`) button and
  a main button that is Live while empty, Send once you type, and Stop while
  streaming; emits haptics. Use this only if you're wiring callbacks yourself.
- `AiLoader` — a pulsing three-dot thinking indicator.

**Controller-bound** (wire to a `UseChatController` — what you usually want):
- `AiChatView` — the batteries-included one-widget chat: transcript + composer +
  layout. The fastest way to drop in a full chat.
- `AiChat` — live transcript with auto-scroll and a thinking loader.
- `AiPromptInput` — the drop-in composer: wraps `AiComposer` and wires it to
  `sendText` / `stop`. Prefer this over `AiComposer`.

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.controller});
  final UseChatController controller; // from flutter_ai_client

  @override
  Widget build(BuildContext context) => Scaffold(
        // Batteries-included: transcript + composer + layout in one widget.
        body: AiChatView(controller: controller),
      );
}
```

Need a custom layout between the transcript and composer? Compose the pieces
yourself instead:

```dart
Scaffold(
  body: Column(
    children: [
      Expanded(child: AiChat(controller: controller)),
      AiPromptInput(controller: controller),
    ],
  ),
);
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

Markdown renders **by default** — headings, lists, bold/italic, links, and fenced
code blocks — via `MarkdownTextRenderer`, so streamed answers format themselves
out of the box. Text flows through an injectable `AiTextRenderer`
(`TextRenderer<Widget>`), so you can swap in `PlainTextRenderer` for raw text, or
your own renderer for LaTeX or custom syntax highlighting:

```dart
// Markdown is the default — this line is optional.
AiChat(controller: controller, textRenderer: const MarkdownTextRenderer());

// Opt out to plain text, or bring your own.
AiChat(controller: controller, textRenderer: const PlainTextRenderer());
```

## Status

Published on pub.dev (see the CHANGELOG); depends on the sibling `flutter_ai`
packages.
See [`example/`](example/) for a full app.

_If `flutter_ai` saves you time, you can [buy me a coffee ☕](https://ko-fi.com/ananmouaz)._

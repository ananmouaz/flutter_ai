<h1 align="center">flutter_ai</h1>

<p align="center"><b>The complete AI chat toolkit for Flutter</b> — streaming, tools, generative UI, voice, and a batteries-included UI kit. Zero state-management lock-in.</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/hero-streaming.gif" width="300" alt="flutter_ai: a streaming answer with chain-of-thought and a generative-UI task card"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_ai_elements"><img src="https://img.shields.io/pub/v/flutter_ai_elements.svg?label=flutter_ai_elements" alt="flutter_ai_elements on pub.dev"/></a>
  <a href="https://github.com/ananmouaz/flutter_ai/actions/workflows/ci.yml"><img src="https://github.com/ananmouaz/flutter_ai/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="License: BSD-3-Clause"/></a>
</p>

<p align="center">
  <b>UI:</b> <a href="packages/flutter_ai_elements">elements</a> ·
  <b>Engine:</b> <a href="packages/flutter_ai_core">core</a> · <a href="packages/flutter_ai_client">client</a> ·
  <b>Providers:</b> <a href="packages/flutter_ai_provider_openai">openai</a> · <a href="packages/flutter_ai_provider_anthropic">anthropic</a> · <a href="packages/flutter_ai_provider_gemini">gemini</a> ·
  <b>Add-ons:</b> <a href="packages/flutter_ai_tools">tools</a> · <a href="packages/flutter_ai_mcp">mcp</a> · <a href="packages/flutter_ai_voice">voice</a><br/>
  <a href="docs/recipes.md">Recipes</a> · <a href="docs/migration-from-vercel-ai-sdk.md">Migrating from the Vercel AI SDK</a> · <a href="demo/">Demo app</a>
</p>

---

**Build AI chat in Flutter in minutes.** A family of small, focused packages —
the Flutter answer to Vercel's AI SDK + AI Elements. Drop in a polished chat UI,
or compose the pieces yourself. Provider-agnostic (OpenAI, Anthropic, Gemini),
state-manager-agnostic, mobile-first.

## Feature gallery

<table>
  <tr>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-streaming.png" width="220" alt="Streaming chat"/><br/>
      <b>Streaming chat</b><br/>
      <sub>Tokens stream in, batched to the frame so high token rates never drop a frame.</sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-generative-ui.png" width="220" alt="Generative UI"/><br/>
      <b>Generative UI</b><br/>
      <sub>Tool results render as live Flutter widgets — task cards, not just JSON.</sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-tools.png" width="220" alt="Tools and function calling"/><br/>
      <b>Tools &amp; agents</b><br/>
      <sub>Function calling and MCP servers flow through the agent loop with no glue code.</sub>
    </td>
  </tr>
  <tr>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-citations.png" width="220" alt="Grounded citations"/><br/>
      <b>Citations</b><br/>
      <sub>Grounded answers stream their web sources as inline citations.</sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-voice.png" width="220" alt="Live voice mode"/><br/>
      <b>Voice</b><br/>
      <sub>An animated live orb over engine-agnostic speech-to-text contracts.</sub>
    </td>
    <td align="center" width="33%">
      <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-theming.png" width="220" alt="Theming, light and dark"/><br/>
      <b>Theming</b><br/>
      <sub>Restyle everything through one <code>AiThemeExtension</code> — light &amp; dark.</sub>
    </td>
  </tr>
</table>

## How it fits together

`core` is the foundation everything stands on · `providers` talk to the AI ·
`client` runs the conversation · `elements` shows it. Tools & voice are optional.

```
                          YOUR FLUTTER APP
                                 │  drops in widgets
                                 ▼
        ┌─────────────────────────────────────────────────┐
        │            flutter_ai_elements   (UI)            │
        │   AiChat · AiPromptInput · AiResponse ·          │
        │   AiLiveSession · AiSources · AiToolGroup ...    │
        └───────────────────────┬─────────────────────────┘
                                 │ bound to
                                 ▼
        ┌─────────────────────────────────────────────────┐
        │           flutter_ai_client   (the brain)        │
        │   UseChatController  — the “useChat” controller  │
        └───────────────────────┬─────────────────────────┘
                                 │ calls LlmProvider.send()
        ┌────────────────┬───────┴────────┬────────────────┐
        ▼                ▼                ▼
  provider_openai   provider_anthropic  provider_gemini   ──►  the AI APIs
        └────────────────┴───────┬────────┴────────────────┘
                                 │ all speak one contract: LlmProvider → AiStreamEvent
                                 ▼
        ┌─────────────────────────────────────────────────┐
        │          flutter_ai_core   (foundation)          │
        │  models · AiStreamEvent · LlmProvider ·          │
        │  MessageProcessor · ToolDefinition               │
        └─────────────────────────────────────────────────┘
              ▲                ▲                  ▲
     optional │       optional │                  │ optional
     ┌────────┴────────┐ ┌─────┴─────────┐ ┌──────┴──────────┐
     │ flutter_ai_tools│ │ flutter_ai_mcp│ │ flutter_ai_voice│
     │  (tool calling) │ │  (MCP tools)  │ │ (speech-to-text)│
     └─────────────────┘ └───────────────┘ └─────────────────┘
```

**What happens when you send a message:**

```
You type → AiPromptInput → UseChatController.sendText()
                              │
                              ▼
                  provider.send(conversation)  ───►  LLM API (streams back)
                              │                            │
            AiStreamEvents  ◄─┴────────────────────────────┘
                              │
            MessageProcessor folds events → updated AiConversation
                              │
            controller notifies → AiChat rebuilds → reply streams in
```

## Quick start

A minimal app is **one UI package + one provider**:

```yaml
dependencies:
  flutter_ai_elements: ^0.1.0
  flutter_ai_provider_openai: ^0.1.0   # or _anthropic / _gemini
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_ai_provider_openai/flutter_ai_provider_openai.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final controller = UseChatController(
    provider: OpenAiProvider(apiKey: const String.fromEnvironment('OPENAI_API_KEY')),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: AiChat(controller: controller)),
                AiPromptInput(controller: controller),
              ],
            ),
          ),
        ),
      );
}
```

That streams responses, renders Markdown/code/tables, and swaps Send↔Stop while
generating. Swap `OpenAiProvider` for `AnthropicProvider` or `GeminiProvider` to
change models — nothing else changes.

`AiPromptInput` is the batteries-included input: bind it to a `UseChatController`
and it sends, stages attachments, and toggles Send/Stop for you. Need full
control of the input UI? Reach for its presentational primitive `AiComposer`
(plain callbacks, no controller) and wire it yourself.

## Which package do I need?

| I want to… | Add |
|---|---|
| A full chat UI, fast | `flutter_ai_elements` (pulls in client + core) |
| Talk to a model | a provider: `…_openai`, `…_anthropic`, or `…_gemini` |
| Drive chat with my own UI | `flutter_ai_client` |
| Tools / function calling | `flutter_ai_tools` |
| Connect to MCP servers | `flutter_ai_mcp` |
| Voice input | `flutter_ai_voice` (+ an STT plugin) |
| Build my own provider/widgets | `flutter_ai_core` only |

## Packages

| Package | Description |
|---|---|
| [`flutter_ai_core`](packages/flutter_ai_core) | Foundation (pure Dart): models, `AiStreamEvent`, `MessageProcessor`, `LlmProvider` & renderer contracts |
| [`flutter_ai_client`](packages/flutter_ai_client) | `UseChatController` — a `Listenable` chat controller (optimistic send, cancel, regenerate, branches, tool results) |
| [`flutter_ai_elements`](packages/flutter_ai_elements) | 30+ UI widgets + `AiThemeExtension`: `AiChat`, `AiPromptInput`, `AiResponse` (Markdown), `AiToolGroup`, `AiReasoning`, `AiSources`, `AiLiveSession`, … |
| [`flutter_ai_tools`](packages/flutter_ai_tools) | Tool calling (`ToolSpec`, `ToolRegistry`) + web-search adapter |
| [`flutter_ai_mcp`](packages/flutter_ai_mcp) | Model Context Protocol (MCP) integration for flutter_ai: connect to MCP servers over Streamable HTTP and expose their tools as flutter_ai tools that flow through the agent loop |
| [`flutter_ai_voice`](packages/flutter_ai_voice) | Engine-agnostic speech-to-text contracts |
| [`flutter_ai_provider_openai`](packages/flutter_ai_provider_openai) | OpenAI-compatible streaming provider (also works with Gemini's OpenAI endpoint) |
| [`flutter_ai_provider_anthropic`](packages/flutter_ai_provider_anthropic) | Anthropic (Claude) Messages API provider |
| [`flutter_ai_provider_gemini`](packages/flutter_ai_provider_gemini) | Native Gemini provider with Google Search **grounding → citations** |

## Demo

A showcase app lives in [`demo/`](demo/) — a live chat (streams reasoning → tool
call → answer → citation), real function calling, Live voice mode, and a gallery
of every element. Run it against a real model:

```bash
cd demo
flutter run --dart-define=GEMINI_API_KEY=your_key   # or OPENAI/ANTHROPIC
```

## Learn more

- [**Recipes**](docs/recipes.md) — a task-oriented cookbook: streaming chat,
  bring-your-own-UI, tool calling / agent loops, structured output, embeddings &
  RAG, token pre-flight & cost, history trimming, persistence & threads, theming,
  generative UI, MCP tools, prompt caching, and error handling.
- [**Migrating from the Vercel AI SDK**](docs/migration-from-vercel-ai-sdk.md) —
  a concept map and side-by-side snippets for developers coming from the
  TypeScript AI SDK (`useChat` → `UseChatController`, `streamText` →
  `LlmProvider.send`, `generateObject`/`embed`/`tool()`, and more).
- [**`demo/`**](demo/) — the runnable example app (see [Demo](#demo) above to run it).

## Development

This is a [pub workspace](https://dart.dev/tools/pub/workspaces) (Dart ≥ 3.6) —
one resolution, one shared strict `analysis_options.yaml`.

```bash
flutter pub get                 # resolve the whole workspace
dart format .                   # format every package
dart analyze                    # lint every package
# run a package's tests:
cd packages/flutter_ai_core && dart test
```

CI runs format + analyze + every package's tests on each PR. To publish, see
[PUBLISHING.md](PUBLISHING.md).

## Stability

Pre-1.0 (`0.1.x`): the API is stabilizing and may change between minor versions —
breaking changes will be called out in each package's `CHANGELOG.md`. The core
contracts (`LlmProvider`, `AiStreamEvent`, `UseChatController`) are the most
settled. We follow [semver](https://semver.org); 1.0 marks an API-stability
commitment.

See [`ROADMAP.md`](ROADMAP.md) for what's planned on the way to 1.0.

## ☕ Support this project

<p align="center">
  <a href="https://ko-fi.com/ananmouaz"><img src="https://storage.ko-fi.com/cdn/kofi3.png?v=6" alt="Buy me a coffee on Ko-fi" height="72"></a>
</p>

<p align="center"><b>If <code>flutter_ai</code> saves you time, <a href="https://ko-fi.com/ananmouaz">buy me a coffee ☕</a> — it keeps the whole family maintained.</b></p>

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and our
[Code of Conduct](CODE_OF_CONDUCT.md). Provider live tests run against real APIs
when you set the relevant key (`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` /
`GEMINI_API_KEY`); they're skipped otherwise.

## License

BSD-3-Clause. See [LICENSE](LICENSE).

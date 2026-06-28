# flutter_ai

[![CI](https://github.com/ananmouaz/flutter_ai/actions/workflows/ci.yml/badge.svg)](https://github.com/ananmouaz/flutter_ai/actions/workflows/ci.yml)
[![License: BSD-3](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

**Build AI chat in Flutter in minutes.** A family of small, focused packages —
the Flutter answer to Vercel's AI SDK + AI Elements. Drop in a polished chat UI,
or compose the pieces yourself. Provider-agnostic (OpenAI, Anthropic, Gemini),
state-manager-agnostic, mobile-first.

<p>
  <img src="demo/screenshots/chat.gif" width="250" alt="flutter_ai chat demo" />
  <img src="demo/screenshots/live_orb.png" width="125" alt="Live voice mode" />
  <img src="demo/screenshots/element_tool_group.png" width="220" alt="Tool calls" />
</p>

<sub>Streaming chat with reasoning, tool calls, citations · Live voice mode · light & dark.</sub>

## How it fits together

`core` is the foundation everything stands on · `providers` talk to the AI ·
`client` runs the conversation · `elements` shows it. Tools & voice are optional.

```
                          YOUR FLUTTER APP
                                 │  drops in widgets
                                 ▼
        ┌─────────────────────────────────────────────────┐
        │            flutter_ai_elements   (UI)            │
        │   AiChat · AiComposer · AiResponse ·             │
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
              ▲                                   ▲
     optional │                                   │ optional
     ┌────────┴────────┐                 ┌────────┴────────┐
     │ flutter_ai_tools│                 │ flutter_ai_voice│
     │  (tool calling) │                 │ (speech-to-text)│
     └─────────────────┘                 └─────────────────┘
```

**What happens when you send a message:**

```
You type → AiComposer → UseChatController.sendText()
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

## Which package do I need?

| I want to… | Add |
|---|---|
| A full chat UI, fast | `flutter_ai_elements` (pulls in client + core) |
| Talk to a model | a provider: `…_openai`, `…_anthropic`, or `…_gemini` |
| Drive chat with my own UI | `flutter_ai_client` |
| Tools / function calling | `flutter_ai_tools` |
| Voice input | `flutter_ai_voice` (+ an STT plugin) |
| Build my own provider/widgets | `flutter_ai_core` only |

## Packages

| Package | Description |
|---|---|
| [`flutter_ai_core`](packages/flutter_ai_core) | Foundation (pure Dart): models, `AiStreamEvent`, `MessageProcessor`, `LlmProvider` & renderer contracts |
| [`flutter_ai_client`](packages/flutter_ai_client) | `UseChatController` — a `Listenable` chat controller (optimistic send, cancel, regenerate, branches, tool results) |
| [`flutter_ai_elements`](packages/flutter_ai_elements) | 30+ UI widgets + `AiThemeExtension`: `AiChat`, `AiComposer`, `AiResponse` (Markdown), `AiToolGroup`, `AiReasoning`, `AiSources`, `AiLiveSession`, … |
| [`flutter_ai_tools`](packages/flutter_ai_tools) | Tool calling (`ToolSpec`, `ToolRegistry`) + web-search adapter |
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

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and our
[Code of Conduct](CODE_OF_CONDUCT.md). Provider live tests run against real APIs
when you set the relevant key (`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` /
`GEMINI_API_KEY`); they're skipped otherwise.

## License

BSD-3-Clause. See [LICENSE](LICENSE).

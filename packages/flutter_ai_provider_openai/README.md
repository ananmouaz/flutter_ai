<h1 align="center">flutter_ai_provider_openai</h1>

<p align="center"><b>OpenAI streaming provider for flutter_ai</b> — Chat Completions mapped to <code>AiStreamEvent</code>s. Works with the public API or any compatible endpoint (Azure, proxies, local servers).</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/hero-streaming.png" width="300" alt="A streamed answer rendered by flutter_ai"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_ai_provider_openai"><img src="https://img.shields.io/pub/v/flutter_ai_provider_openai.svg" alt="flutter_ai_provider_openai on pub.dev"/></a>
  <a href="https://pub.dev/packages/flutter_ai_provider_openai"><img src="https://img.shields.io/pub/points/flutter_ai_provider_openai.svg" alt="pub points"/></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="License: BSD-3-Clause"/></a>
</p>

<p align="center">
  <b>Family:</b> <a href="../../README.md">flutter_ai</a> ·
  <a href="../flutter_ai_core">core</a> · <a href="../flutter_ai_client">client</a> · <a href="../flutter_ai_elements">elements</a> ·
  <a href="../flutter_ai_provider_anthropic">anthropic</a> · <a href="../flutter_ai_provider_gemini">gemini</a><br/>
  <a href="../../docs/recipes.md">Recipes</a> · <a href="../../docs/migration-from-vercel-ai-sdk.md">Migrating from the Vercel AI SDK</a>
</p>

<p align="center"><sub>Streamed responses render through <code>flutter_ai_elements</code> (<code>AiResponse</code>).</sub></p>

---

An OpenAI-compatible `LlmProvider` for the [`flutter_ai`](../../README.md) family.

Streams the OpenAI Chat Completions API and maps each chunk to
`flutter_ai_core` `AiStreamEvent`s — text deltas, streamed tool calls, and finish
reasons. Works with the public OpenAI endpoint or any compatible server (Azure
OpenAI, proxies, local servers) via a custom base URL.

## Usage

```dart
import 'package:flutter_ai_provider_openai/flutter_ai_provider_openai.dart';

final provider = OpenAiProvider(
  apiKey: const String.fromEnvironment('OPENAI_API_KEY'),
  defaultModel: 'gpt-4o-mini',
);

// Drive it with flutter_ai_client's UseChatController:
final controller = UseChatController(provider: provider);
controller.sendText('Hello!');
```

Point it elsewhere with `baseUrl`:

```dart
OpenAiProvider(
  apiKey: key,
  baseUrl: Uri.parse('https://my-proxy.example.com/v1'),
);
```

The HTTP client is injectable (`client:`) for testing or custom transport.

## Status

Published on pub.dev (see the CHANGELOG); depends on `flutter_ai_core`. The
request/response mapping is **unit-tested against recorded SSE chunks**.

_If `flutter_ai` saves you time, you can [buy me a coffee ☕](https://ko-fi.com/ananmouaz)._

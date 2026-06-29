# flutter_ai_provider_openai

## ☕ Support this project

<p align="center">
  <a href="https://ko-fi.com/ananmouaz"><img src="https://storage.ko-fi.com/cdn/kofi3.png?v=6" alt="Buy me a coffee on Ko-fi" height="72"></a>
</p>

<p align="center"><b>If <code>flutter_ai</code> saves you time, <a href="https://ko-fi.com/ananmouaz">buy me a coffee ☕</a> — it keeps the whole family maintained.</b></p>

---

<p align="center"><img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/demo/screenshots/element_response.png" width="300" alt="Streamed Markdown response"/></p>

<sub>Streamed responses render through <code>flutter_ai_elements</code> (<code>AiResponse</code>).</sub>

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

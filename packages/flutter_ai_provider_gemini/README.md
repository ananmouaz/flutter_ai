<h1 align="center">flutter_ai_provider_gemini</h1>

<p align="center"><b>Native Google Gemini provider for flutter_ai</b> — streaming, function calling, and <b>Google Search grounding → web citations</b> rendered inline.</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/section-citations.png" width="300" alt="A grounded answer streaming its web source citations"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_ai_provider_gemini"><img src="https://img.shields.io/pub/v/flutter_ai_provider_gemini.svg" alt="flutter_ai_provider_gemini on pub.dev"/></a>
  <a href="https://pub.dev/packages/flutter_ai_provider_gemini"><img src="https://img.shields.io/pub/points/flutter_ai_provider_gemini.svg" alt="pub points"/></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="License: BSD-3-Clause"/></a>
</p>

<p align="center">
  <b>Family:</b> <a href="../../README.md">flutter_ai</a> ·
  <a href="../flutter_ai_core">core</a> · <a href="../flutter_ai_client">client</a> · <a href="../flutter_ai_elements">elements</a> ·
  <a href="../flutter_ai_provider_openai">openai</a> · <a href="../flutter_ai_provider_anthropic">anthropic</a><br/>
  <a href="../../docs/recipes.md">Recipes</a> · <a href="../../docs/migration-from-vercel-ai-sdk.md">Migrating from the Vercel AI SDK</a>
</p>

<p align="center"><sub>With grounding enabled, answers stream <b>source citations</b> (<code>AiSources</code> / <code>AiInlineCitation</code>).</sub></p>

---

A **native** Google Gemini [`LlmProvider`](../flutter_ai_core) for the
`flutter_ai` family. It streams Gemini's `streamGenerateContent` endpoint and
maps each chunk to `AiStreamEvent`s.

Why native (vs. the OpenAI-compatible Gemini endpoint): it speaks Gemini's own
protocol, which unlocks **Google Search grounding** — grounded answers stream
their web **sources back as `SourcePart` citations** (rendered by `AiSources` /
`AiInlineCitation`). It also supports function calling and thinking.

## Usage

```dart
import 'package:flutter_ai_provider_gemini/flutter_ai_provider_gemini.dart';

final provider = GeminiProvider(
  apiKey: const String.fromEnvironment('GEMINI_API_KEY'),
  enableGrounding: true, // attach the Google Search tool → web citations
);

final controller = UseChatController(
  provider: provider,
  options: const AiRequestOptions(model: 'gemini-2.5-flash'),
);
```

## Notes

- **Grounding**: set `enableGrounding: true` (or pass a `googleSearch` tool via
  `AiRequestOptions.extra`). Grounded responses emit `SourcePart`s for each web
  source.
- **Function calling**: pass `ToolDefinition`s; the model's `functionCall`s
  stream as tool-call events, and tool results map to `functionResponse` parts
  (the function name is recovered from the matching call).
- **Config**: `temperature` / `maxOutputTokens` are sent under
  `generationConfig`; arbitrary extra request fields go via
  `AiRequestOptions.extra`.
- **Images**: user-message image attachments (`FilePart` with an `image/*`
  media type) are sent as `inlineData`/`fileData`. Other document types are not
  yet sent.
- **Retry**: transient failures (429/5xx, network) are retried with backoff
  honoring `Retry-After` (`maxRetries`, default 2).

## Status

The request/response mapping is unit-tested against recorded SSE chunks. Supply
an API key to use it against the live API.

## ☕ Support this project

<p align="center">
  <a href="https://ko-fi.com/ananmouaz"><img src="https://storage.ko-fi.com/cdn/kofi3.png?v=6" alt="Buy me a coffee on Ko-fi" height="72"></a>
</p>

<p align="center"><b>If <code>flutter_ai</code> saves you time, <a href="https://ko-fi.com/ananmouaz">buy me a coffee ☕</a> — it keeps the whole family maintained.</b></p>

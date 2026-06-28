# flutter_ai_provider_gemini

<p align="center"><img src="../../demo/screenshots/element_sources.png" width="300" alt="Grounded source citations"/></p>

<sub>With grounding enabled, answers stream <b>source citations</b> (<code>AiSources</code> / <code>AiInlineCitation</code>).</sub>

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

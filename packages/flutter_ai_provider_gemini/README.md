# flutter_ai_provider_gemini

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
- This release maps **text, thinking, tool, and grounding content**. Image/
  document parts are not yet sent.

## Status

The request/response mapping is unit-tested against recorded SSE chunks. Supply
an API key to use it against the live API.

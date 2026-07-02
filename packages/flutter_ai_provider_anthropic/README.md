<h1 align="center">flutter_ai_provider_anthropic</h1>

<p align="center"><b>Anthropic (Claude) provider for flutter_ai</b> — streams the Messages API with extended thinking and tool use, mapped to <code>AiStreamEvent</code>s so the rest of the family works against Claude unchanged.</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/hero-streaming.png" width="300" alt="A streamed answer with reasoning, a tool call, and the final answer"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_ai_provider_anthropic"><img src="https://img.shields.io/pub/v/flutter_ai_provider_anthropic.svg" alt="flutter_ai_provider_anthropic on pub.dev"/></a>
  <a href="https://pub.dev/packages/flutter_ai_provider_anthropic"><img src="https://img.shields.io/pub/points/flutter_ai_provider_anthropic.svg" alt="pub points"/></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="License: BSD-3-Clause"/></a>
</p>

<p align="center">
  <b>Family:</b> <a href="../../README.md">flutter_ai</a> ·
  <a href="../flutter_ai_core">core</a> · <a href="../flutter_ai_client">client</a> · <a href="../flutter_ai_elements">elements</a> ·
  <a href="../flutter_ai_provider_openai">openai</a> · <a href="../flutter_ai_provider_gemini">gemini</a><br/>
  <a href="../../docs/recipes.md">Recipes</a> · <a href="../../docs/migration-from-vercel-ai-sdk.md">Migrating from the Vercel AI SDK</a>
</p>

---

An Anthropic (Claude) [`LlmProvider`](../flutter_ai_core) for the `flutter_ai`
family. It streams the Anthropic **Messages API** and maps each event to
`AiStreamEvent`s, so the controllers and UI in `flutter_ai_client` /
`flutter_ai_elements` work against Claude unchanged.

- Streams text, **extended thinking**, **tool use**, and finish reasons.
- Maps `flutter_ai` conversations to Anthropic's wire format (system folded into
  the top-level `system` field; assistant tool calls → `tool_use`; tool results
  → `tool_result`).
- Injectable `http.Client` for testing and custom transport.

## Usage

```dart
import 'package:flutter_ai_provider_anthropic/flutter_ai_provider_anthropic.dart';

final provider = AnthropicProvider(
  apiKey: const String.fromEnvironment('ANTHROPIC_API_KEY'),
  // defaultModel: 'claude-opus-4-8',  // override per request via AiRequestOptions
);

await for (final event in provider.send(conversation, tools: tools)) {
  // feed into a MessageProcessor / UseChatController
}
```

Wire it into a controller:

```dart
final controller = UseChatController(
  provider: AnthropicProvider(apiKey: myKey),
  options: const AiRequestOptions(model: 'claude-opus-4-8'),
);
```

## Notes

- **`max_tokens` is required** by the API. Set it via
  `AiRequestOptions.maxOutputTokens`, or rely on `AnthropicProvider`'s
  `defaultMaxTokens` (4096).
- **Sampling parameters** (`temperature`) are forwarded only when set. Newer
  Claude models reject them — leave it unset for those.
- **Extended thinking**: pass it through `AiRequestOptions.extra`, e.g.
  `extra: {'thinking': {'type': 'adaptive'}}`. Thinking text streams as
  `ReasoningDelta` events (`AiReasoning` in the UI).
- **Images**: user-message image attachments (`FilePart` with an `image/*`
  media type) are sent as base64 or URL image blocks. Other document types are
  not yet sent.
- **Retry**: transient failures (429/5xx, network) are retried with backoff
  honoring `Retry-After` (`maxRetries`, default 2).

## Status

The request/response mapping is unit-tested against recorded SSE events. Supply
an API key to use it against the live API.

_If `flutter_ai` saves you time, you can [buy me a coffee ☕](https://ko-fi.com/ananmouaz)._

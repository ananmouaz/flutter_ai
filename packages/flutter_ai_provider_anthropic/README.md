# flutter_ai_provider_anthropic

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

# Migrating from the Vercel AI SDK

Coming from the [Vercel AI SDK](https://sdk.vercel.ai) (TypeScript) and the AI
Elements components? `flutter_ai` is the Flutter answer: the same parts-based
message model and `useChat`-style controller, the same streaming/tool/structured-
output vocabulary — re-expressed in idiomatic Dart.

**The key philosophical difference:** flutter_ai is **un-opinionated about state
management, and UI is optional**. `flutter_ai_core` and `flutter_ai_client` are
pure Dart with no Flutter dependency — you can run the whole conversation loop on
a server, in a CLI, or in a test, and only add `flutter_ai_elements` when you want
widgets. The Vercel SDK's React hooks (`useChat`) are framework-bound; flutter_ai's
`UseChatController` is just a `ChangeNotifier` you bind with `ListenableBuilder`,
or adapt to Bloc / Riverpod / Provider.

## Concept map

| Vercel AI SDK | flutter_ai | Notes |
|---|---|---|
| `useChat()` hook | `UseChatController` + `ListenableBuilder` | A `ChangeNotifier`, not a hook. UI binding is optional. |
| `streamText()` | `provider.send(conversation)` → `Stream<AiStreamEvent>` | The streaming contract is a `sealed` event set folded by `MessageProcessor`. |
| `generateText()` | drain `provider.send(...)` (or use the controller) | No dedicated one-shot helper; collect `TextDelta`s, or just read `controller.messages` after the turn. |
| `generateObject()` | `provider.generateObject(convo, format:)` | `GenerateObject` extension on `LlmProvider`. |
| `streamObject()` | `provider.streamObject(convo, format:)` | Yields growing prefixes of the object. |
| `embed()` / `embedMany()` | `(provider as EmbeddingProvider).embed([...])` | One method, batch in/out. Optional capability — check `provider is EmbeddingProvider`. |
| `tool({ parameters, execute })` | `ToolSpec` (`flutter_ai_tools`) or `ToolDefinition` (declaration only) | `ToolDefinition` is pure data (no executor); `ToolSpec` adds `execute`. |
| `tools: { … }` | `tools: [ToolDefinition(...)]` | A list, not a keyed object. Names are the keys. |
| `maxSteps` | `maxSteps` on `UseChatController` | Same meaning: max model calls per turn (default 8). |
| `experimental_telemetry` / `onStepFinish` | `controller.events` stream | Raw event stream as the analytics/hook escape hatch. |
| `UIMessage` + `parts` | `AiMessage` + `List<AiPart>` | `TextPart`, `ReasoningPart`, `ToolCallPart`, `ToolResultPart`, `FilePart`, `SourcePart`, `DataPart`. |
| `messages` / `setMessages` | `controller.messages` / `controller.clear()` + `submit` | Transcript is read-only; mutate via `sendText`/`submit`/`editMessage`/`regenerate`. |
| `@ai-sdk/openai` | `flutter_ai_provider_openai` (`OpenAiProvider`) | |
| `@ai-sdk/anthropic` | `flutter_ai_provider_anthropic` (`AnthropicProvider`) | |
| `@ai-sdk/google` | `flutter_ai_provider_gemini` (`GeminiProvider`) | Native endpoint → Google Search grounding → `SourcePart` citations. |
| AI Elements (`<Conversation>`, `<Message>`, `<Response>`, …) | `flutter_ai_elements` (`AiChat`, `AiConversationView`, `AiResponse`, `AiSources`, …) | Same component vocabulary, rendered through `AiThemeExtension`. |
| Provider registry / `createProviderRegistry` | construct providers directly; `controller.setProvider(...)` | No global registry; swap at runtime with `setProvider`/`setOptions`. |

## Side-by-side

### Chat: `useChat` → `UseChatController`

```ts
// Vercel AI SDK (React)
const { messages, input, handleSubmit, stop } = useChat({
  api: '/api/chat',
});
```

```dart
// flutter_ai
final controller = UseChatController(
  provider: OpenAiProvider(apiKey: key),
);

// In a widget:
ListenableBuilder(
  listenable: controller,
  builder: (context, _) => Column(children: [
    for (final m in controller.messages) Text(m.text),
    AiPromptInput(controller: controller), // or call controller.sendText(...)
  ]),
);
// controller.stop() cancels an in-flight turn.
```

Note: in the Vercel SDK the model runs server-side behind `api`. flutter_ai calls
the provider **directly from the client** by default (good for prototypes and
local tooling); for production, point a provider's `baseUrl` at your own proxy so
keys stay server-side.

### Streaming: `streamText` → `provider.send`

```ts
// Vercel AI SDK
const result = streamText({ model: openai('gpt-4o'), prompt: 'Hi' });
for await (const delta of result.textStream) process.stdout.write(delta);
```

```dart
// flutter_ai — send returns a Stream<AiStreamEvent>
final convo = AiConversation(id: 'c', messages: const [
  AiMessage(id: '1', role: AiRole.user, parts: [TextPart('Hi')]),
]);
await for (final event in provider.send(convo)) {
  if (event is TextDelta) stdout.write(event.delta);
}
```

The stream carries more than text: `ReasoningDelta`, `ToolCallStarted/Delta/Ready`,
`ToolResultReceived`, `PartReceived`, `MessageFinished` (with `AiUsage`), and
`StreamErrorEvent`. Because `AiStreamEvent` is `sealed`, a `switch` over it is
exhaustively checked.

### Structured output: `generateObject` → `GenerateObject`

```ts
// Vercel AI SDK
const { object } = await generateObject({
  model: openai('gpt-4o'),
  schema: z.object({ title: z.string() }),
  prompt: 'Make a recipe',
});
```

```dart
// flutter_ai — pass a JSON Schema via AiResponseFormat (no Zod equivalent)
const format = AiResponseFormat(
  name: 'recipe',
  schema: {
    'type': 'object',
    'properties': {'title': {'type': 'string'}},
    'required': ['title'],
  },
);
final object = await provider.generateObject(convo, format: format);
// Streaming partials:
await for (final partial in provider.streamObject(convo, format: format)) { … }
```

**No 1:1 for Zod.** The Vercel SDK derives the schema from a Zod object;
flutter_ai takes a raw JSON Schema `Map`. There is no built-in Zod-style typed
codec — `generateObject` returns `Map<String, Object?>`, which you decode into
your own model class.

### Tools: `tool()` + `maxSteps`

```ts
// Vercel AI SDK
const result = streamText({
  model: openai('gpt-4o'),
  maxSteps: 5,
  tools: {
    getWeather: tool({
      parameters: z.object({ city: z.string() }),
      execute: async ({ city }) => fetchWeather(city),
    }),
  },
});
```

```dart
// flutter_ai — declaration + executor + agent loop on the controller
final registry = ToolRegistry([
  ToolSpec(
    name: 'getWeather',
    description: 'Get the weather for a city.',
    parametersSchema: {
      'type': 'object',
      'properties': {'city': {'type': 'string'}},
      'required': ['city'],
    },
    execute: (args) => fetchWeather(args['city'] as String),
  ),
]);

final controller = UseChatController(
  provider: provider,
  tools: registry.definitions,
  maxSteps: 5,
  onToolCalls: (calls, signal) => Future.wait(calls.map(registry.run)),
);
```

Like the Vercel SDK's multi-step tool calling, the controller auto-loops:
execute calls → append results → re-prompt, until no pending calls or `maxSteps`.
flutter_ai additionally **validates** each tool call's arguments against its
`parametersSchema` before executing (on by default); a violating call is answered
with an error result so the model can retry, rather than being run.

### Embeddings: `embed` / `embedMany` → `EmbeddingProvider.embed`

```ts
// Vercel AI SDK
const { embeddings } = await embedMany({
  model: openai.embedding('text-embedding-3-small'),
  values: ['a', 'b'],
});
```

```dart
// flutter_ai — one batched method; capability is opt-in
if (provider is EmbeddingProvider) {
  final embeddings = await (provider as EmbeddingProvider).embed(
    ['a', 'b'],
    model: 'text-embedding-3-small',
  );
  // embeddings[i].values is the vector; embeddings[i].index aligns to input i.
}
```

There is no separate `embed` vs `embedMany` — `embed` always takes a list.
**OpenAI and Gemini implement `EmbeddingProvider`; Anthropic does not**, so always
gate the call behind the `is EmbeddingProvider` check.

### Messages & parts: `UIMessage` → `AiMessage`

Both model a message as an **ordered list of typed parts**. The mapping:

| Vercel part `type` | flutter_ai `AiPart` |
|---|---|
| `text` | `TextPart` |
| `reasoning` | `ReasoningPart` |
| `tool-call` (tool invocation) | `ToolCallPart` |
| `tool-result` | `ToolResultPart` |
| `file` | `FilePart` (`url` or inline `bytes`) |
| `source` / citation | `SourcePart` |
| custom `data-*` | `DataPart` (drives generative UI) |

```dart
final message = AiMessage(
  id: 'm1',
  role: AiRole.user, // user | assistant | system | tool
  parts: const [TextPart('Summarize this PDF')],
);
```

`AiMessage` carries a `status` (e.g. `streaming` / `complete`), an optional
`AiUsage`, and a `FinishReason` — the controller and providers manage these as a
turn progresses.

## Things with no direct equivalent (yet)

- **Zod / typed schemas** — schemas are raw JSON Schema `Map`s; decode results
  into your own classes.
- **Server-side framework adapters** (Next.js route handlers, `toDataStreamResponse`,
  RSC `streamUI`) — flutter_ai targets the client; for a backend, run the pure-Dart
  `core`/`client` packages on a server and put your own transport in front.
- **A global provider registry** — construct providers directly and switch with
  `controller.setProvider` / `setOptions`.
- **`useCompletion` / `useAssistant`** — use the same `UseChatController` (or
  `provider.send` directly) for these shapes.

## See also

- [Recipes](recipes.md) — copy-pasteable snippets for the tasks above.
- [`demo/`](../demo/) — a runnable app exercising chat, tools, grounding, and
  generative UI.
- Root [README](../README.md) — package overview and quick start.

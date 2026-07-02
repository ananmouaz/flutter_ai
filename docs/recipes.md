# Recipes

A task-oriented cookbook for `flutter_ai`. Each recipe is a short, self-contained
snippet you can copy and adapt. Most snippets read the API key from a compile-time
define — run with `--dart-define=OPENAI_API_KEY=…` (or `ANTHROPIC_API_KEY` /
`GEMINI_API_KEY`).

For a full, runnable app that wires many of these together, see [`demo/`](../demo/).

- [1. Minimal streaming chat](#1-minimal-streaming-chat)
- [2. Bring your own UI](#2-bring-your-own-ui)
- [3. Tool calling / agent loop](#3-tool-calling--agent-loop)
- [4. Structured output](#4-structured-output-generateobject--streamobject)
- [5. Embeddings for RAG](#5-embeddings-for-rag)
- [6. Token pre-flight & cost](#6-token-pre-flight--cost)
- [7. Long-conversation history trimming](#7-long-conversation-history-trimming)
- [8. Persistence & threads](#8-persistence--threads)
- [9. Theming](#9-theming)
- [10. Generative UI](#10-generative-ui)
- [11. MCP tools](#11-mcp-tools)
- [12. Prompt caching & error handling](#12-prompt-caching--error-handling)

---

## 1. Minimal streaming chat

A provider, a `UseChatController`, and `AiChat` + `AiPromptInput`. That is a
complete streaming chat surface — it renders Markdown/code, swaps Send↔Stop while
generating, and keeps the full transcript.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_ai_provider_openai/flutter_ai_provider_openai.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = UseChatController(
    provider: OpenAiProvider(
      apiKey: const String.fromEnvironment('OPENAI_API_KEY'),
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: AiChat(controller: controller)),
              AiPromptInput(controller: controller),
            ],
          ),
        ),
      );
}
```

Swap `OpenAiProvider` for `AnthropicProvider` or `GeminiProvider` — nothing else
changes. `AiChatView` is an alternative all-in-one surface that bundles the
conversation list + input with extra hooks (`emptyState`, `hintText`,
`maxContentWidth`, `onPickAttachment`, `onVoice`, `onLive`).

---

## 2. Bring your own UI

`UseChatController` is a `ChangeNotifier` — it imposes no state-management
library. Drive any UI by listening to it. Here `ListenableBuilder` rebuilds a
custom message list, and the batteries-included `AiPromptInput` still handles
sending and the Send/Stop toggle.

```dart
ListenableBuilder(
  listenable: controller,
  builder: (context, _) {
    final messages = controller.messages;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, i) {
              final m = messages[i];
              return ListTile(
                leading: Text(m.role.name),
                title: AiResponse(text: m.text), // streaming-aware Markdown
              );
            },
          ),
        ),
        if (controller.status.isBusy) const LinearProgressIndicator(),
        AiPromptInput(controller: controller),
      ],
    );
  },
)
```

For full input control, use the presentational `AiComposer` (plain
`onSend`/`onStop` callbacks, no controller) and call `controller.sendText(text)`
yourself. The raw `controller.events` stream is an escape hatch for analytics or
a custom state layer (Bloc/Riverpod/Provider).

---

## 3. Tool calling / agent loop

Pass `tools` so the model knows what it can call, and `onToolCalls` to execute
them. The controller then runs an **automatic agent loop**: it executes pending
tool calls, appends the results, and re-prompts the model — repeating until a
turn has no pending calls or `maxSteps` model calls have run.

```dart
final tools = [
  const ToolDefinition(
    name: 'get_weather',
    description: 'Get the current weather for a city.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string'},
      },
      'required': ['city'],
    },
  ),
];

final controller = UseChatController(
  provider: provider,
  tools: tools,
  maxSteps: 8, // upper bound on model calls per turn (default 8)
  onToolCalls: (calls, signal) async {
    return [
      for (final call in calls)
        ToolResultPart(
          toolCallId: call.toolCallId,
          result: await fetchWeather(call.args['city'] as String),
        ),
    ];
  },
);
```

**Argument validation.** When a tool declares a non-empty `parametersSchema`,
the controller validates each model-produced call against it *before* running
`onToolCalls` (this is on by default — `validateToolArgs: true`). A call whose
arguments violate the schema is **not executed**; instead an error
`ToolResultPart` describing the violations is fed back to the model so it can
correct itself (still bounded by `maxSteps`). Tools with no schema, and calls for
unknown tool names, skip validation.

**Cancellation.** The second argument is an `AiToolCallSignal`. The controller
cancels it if the turn is stopped (`controller.stop()`), replaced by a new turn,
or the controller is disposed while your executor is still running — so a
long-running tool can abort instead of finishing only to have its result
discarded:

```dart
onToolCalls: (calls, signal) async {
  final result = await Future.any([fetchSlow(calls.first), signal.whenCancelled]);
  if (signal.isCancelled) return const []; // bail out, nothing to feed back
  return [ToolResultPart(toolCallId: calls.first.toolCallId, result: result)];
},
```

Prefer to drive tools yourself? Omit `onToolCalls`: the turn ends with the tool
calls, and you call `controller.addToolResults([...])` manually. The
`flutter_ai_tools` package's `ToolRegistry` pairs declarations with executors and
turns a `ToolCallPart` into a `ToolResultPart` (catching failures as error
results):

```dart
final registry = ToolRegistry([
  ToolSpec(
    name: 'get_weather',
    description: 'Get the current weather for a city.',
    parametersSchema: { /* … */ },
    execute: (args) => fetchWeather(args['city'] as String),
  ),
]);

final controller = UseChatController(
  provider: provider,
  tools: registry.definitions,
  onToolCalls: (calls, signal) =>
      Future.wait(calls.map(registry.run)),
);
```

---

## 4. Structured output (`generateObject` / `streamObject`)

The `GenerateObject` extension is layered on any `LlmProvider`. Give it an
`AiResponseFormat` (a JSON Schema) and it returns a decoded `Map`. Each provider
routes this to its native mechanism (OpenAI `response_format`, Gemini
`responseSchema`, Anthropic a forced tool).

```dart
const format = AiResponseFormat(
  name: 'recipe',
  schema: {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'steps': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['title', 'steps'],
  },
);

final convo = AiConversation(id: 'q', messages: const [
  AiMessage(
    id: '1',
    role: AiRole.user,
    parts: [TextPart('Give me a recipe for pancakes.')],
  ),
]);

// One-shot: decode the complete object (throws FormatException on bad JSON).
final object = await provider.generateObject(convo, format: format);
print(object['title']);

// Streaming: yields growing prefixes of the object as it generates.
await for (final partial in provider.streamObject(convo, format: format)) {
  setState(() => _draft = partial);
}
```

---

## 5. Embeddings for RAG

Embeddings are an **optional** provider capability (`EmbeddingProvider`).
**OpenAI and Gemini implement it; Anthropic does not.** Check at runtime with a
type test before calling `embed` — never assume a provider supports it.

```dart
final provider = OpenAiProvider(apiKey: key); // or GeminiProvider

if (provider is EmbeddingProvider) {
  final docs = ['Flutter is a UI toolkit.', 'Dart is a language.'];
  final embeddings = await (provider as EmbeddingProvider).embed(docs);
  // embeddings[i].values is the dense vector for docs[i];
  // embeddings[i].index re-associates a vector with its source input.
  for (final e in embeddings) {
    store.upsert(docs[e.index ?? 0], e.values);
  }
}
```

For RAG, embed your documents once, store the vectors, then at query time embed
the question, find the nearest documents (cosine similarity over `values`), and
inject them into the conversation as context before calling `provider.send`.
`embed` takes an optional `model:` to pick a specific embedding model.

---

## 6. Token pre-flight & cost

Counting tokens *before* sending is an optional capability (`TokenCounter`),
implemented by `GeminiProvider`. Use it for context-window guards or cost
estimates; gate it behind a `provider is TokenCounter` check.

```dart
if (provider is TokenCounter) {
  final tokens = await (provider as TokenCounter)
      .countTokens(conversation, tools: tools);
  if (tokens > 900000) {
    // too big — trim before sending (see recipe 7)
  }
}
```

After a turn, estimate cost from the conversation's accumulated usage.
`controller.totalUsage` sums usage across every message; `AiUsage.estimateCost`
takes per-million-token prices and handles cached/cache-write input separately so
they are never double-counted at the base rate.

```dart
final usage = controller.totalUsage; // AiUsage? — null if none reported
final cost = usage?.estimateCost(
  inputPer1M: 0.15,
  outputPer1M: 0.60,
  cachedInputPer1M: 0.075, // optional: prompt-cache reads
);
```

A no-counter provider can still approximate a budget with
`trimToApproxTokenBudget` (recipe 7), which estimates `ceil(textLength / 4)`
tokens per message.

---

## 7. Long-conversation history trimming

The controller keeps the **full** transcript in memory (so the UI can scroll the
whole session), but you can bound what each *request* costs with `trimHistory`.
It maps the stored conversation to the smaller one actually sent; the stored
transcript is never trimmed. Two ready-made strategies are in `flutter_ai_client`:

```dart
// Keep the system prefix + the most recent 20 non-system messages.
final controller = UseChatController(
  provider: provider,
  trimHistory: keepLastMessages(20),
);

// Or keep as many recent messages as fit in ~8k approximate tokens.
final controller = UseChatController(
  provider: provider,
  trimHistory: trimToApproxTokenBudget(8000), // ~4 chars/token heuristic
);
```

Both always preserve leading `system` messages and avoid starting the kept window
on an orphaned `tool` result (which strict providers reject). For deeply
interleaved tool calls, pass your own
`AiConversation Function(AiConversation)`.

---

## 8. Persistence & threads

The controller is in-memory only. Implement `ChatStore` against any backend
(file, `shared_preferences`, SQLite, HTTP) — `AiConversation`/`AiMessage`/`AiPart`
are all JSON-serializable. `attachStore` auto-saves on change once a turn settles
(debounced, skipped mid-stream) and returns a disposer.

```dart
// Seed from storage, then auto-save.
final controller = UseChatController(
  provider: provider,
  initial: await store.load('thread-42'),
);
final detach = attachStore(controller, store, 'thread-42');

// ...later, before controller.dispose():
detach(); // flushes any pending save
```

For a sidebar / thread list, implement `ChatThreadStore` (adds `listThreads` and
`delete`). `autoTitle(conversation)` derives a short title from the first user
message. `InMemoryChatThreadStore` is a ready store for demos and prototyping.

```dart
final store = InMemoryChatThreadStore();
final threads = await store.listThreads(); // newest first → drive AiConversationList
```

---

## 9. Theming

Styling lives in `AiThemeExtension`, attached to `ThemeData.extensions`. Start
from `.fallback()` (light) or `.dark()` and `copyWith` the tokens you care about —
reading width (`maxContentWidth`), link color, orb color, accent, etc.

```dart
MaterialApp(
  theme: ThemeData.light().copyWith(
    extensions: [
      AiThemeExtension.fallback().copyWith(
        maxContentWidth: 680,            // reading width on wide screens
        linkColor: const Color(0xFF2563EB),
        orbColor: const Color(0xFF2F7BE6),
        accentColor: const Color(0xFF7C3AED),
      ),
    ],
  ),
  darkTheme: ThemeData.dark().copyWith(
    extensions: [AiThemeExtension.dark()],
  ),
  // ...
)
```

Read the active theme anywhere with `AiThemeExtension.of(context)`. A
`maxContentWidth` passed directly to a widget (e.g. `AiChat`) overrides the theme
value.

---

## 10. Generative UI

Let the model render real Flutter widgets instead of just text. The model emits a
`DataPart` naming a registered `dataType` plus a `data` map; you resolve it
against a strict allowlist (`AiWidgetRegistry`) — only explicitly registered types
render, never via reflection. `AiDataView` looks up and builds the widget.

```dart
final registry = AiWidgetRegistry()
  ..register('weather_card', (context, data) {
    return WeatherCard(
      city: data['city'] as String,
      tempC: (data['tempC'] as num).toDouble(),
    );
  });

// In your message builder, for a DataPart:
AiDataView(
  part: part,            // a DataPart
  registry: registry,
  fallback: const SizedBox.shrink(), // shown if dataType is unregistered
)
```

A `DataPart` can arrive over the stream (as a `PartReceived` event) or be produced
by a tool result you map into one.

---

## 11. MCP tools

Connect to a Model Context Protocol server over Streamable HTTP, adapt its tools
to flutter_ai `ToolSpec`s with `mcpToolSpecs`, and feed them through the same
agent loop as native tools.

```dart
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_mcp/flutter_ai_mcp.dart';
import 'package:flutter_ai_tools/flutter_ai_tools.dart';

final mcp = await StreamableHttpMcpConnection.connect(
  baseUrl: 'https://my-mcp-server.example.com',
  headers: {'Authorization': 'Bearer …'},
);

final registry = ToolRegistry(await mcpToolSpecs(mcp));

final controller = UseChatController(
  provider: provider,
  tools: registry.definitions,       // advertise MCP tools to the model
  onToolCalls: (calls, signal) =>            // execute them via the MCP server
      Future.wait(calls.map(registry.run)),
);
```

Each spec's executor calls back into the MCP server, so MCP tools and native
tools mix freely in one `ToolRegistry`.

---

## 12. Prompt caching & error handling

**Prompt caching.** Set `AiRequestOptions.cachePrompt` to hint that the stable
prefix (system instructions + tools) should be cached. Anthropic applies explicit
`cache_control` markers; OpenAI and Gemini cache automatically, so it is a no-op
there. Cache reads/writes show up in `AiUsage` (`cachedInputTokens`,
`cacheCreationTokens`) and are priced separately by `estimateCost`.

```dart
final controller = UseChatController(
  provider: AnthropicProvider(apiKey: key),
  options: const AiRequestOptions(cachePrompt: true),
);
```

**Structured error handling.** A failed provider request surfaces as a
`StreamErrorEvent` whose `error` is a typed `LlmException` subtype, so you can
branch on the *kind* of failure instead of string-matching. After a failed turn,
`controller.error` holds it.

```dart
switch (controller.error) {
  case LlmAuthException():        // 401/403 — bad/missing key
    showBanner('Check your API key.');
  case LlmRateLimitException(:final retryAfter): // 429
    scheduleRetry(after: retryAfter);
  case LlmServerException():       // 5xx (incl. Anthropic 529 overloaded)
    showBanner('The model is having trouble. Try again.');
  case LlmRequestException():      // other 4xx — malformed request
    showBanner('That request was rejected.');
  case null:
    break; // no error
  default:
    showBanner('Something went wrong.');
}
```

The same typing is available on a raw `StreamErrorEvent.error` if you consume
`controller.events` directly. `AiErrorBanner` is a ready widget for surfacing
`controller.error` in the UI.

# Spec: `flutter_ai_tools` + Attachments

Two related concerns: tool/agent-action contracts (`flutter_ai_tools`) and
attachment models/widgets (in core + elements, splittable later into
`flutter_ai_attachments`).

---

## Part A — `flutter_ai_tools`

### Purpose

Provider-neutral contracts for tool calling, web search, and structured actions,
plus the visualization contract the UI uses to render them.

### Target users

- App developers exposing functions/tools to a model.
- Provider authors mapping native tool-calling formats to our contract.

### Problems solved

- One way to declare a tool (name, description, JSON schema, executor) regardless
  of provider.
- A clean model for streaming tool-call args and surfacing results — including
  **parallel** calls.

### Non-goals

- No reflection-based auto-binding of Dart functions (AOT-unsafe). Tools are
  explicitly declared.
- No built-in web-search backend — we ship the *contract* + adapters, not a
  search service.

### Core API

```dart
class ToolSpec {
  final String name;
  final String description;
  final Map<String, dynamic> parametersSchema;     // JSON Schema
  final FutureOr<Object?> Function(Map<String, dynamic> args)? execute; // optional client-side
}

// Tool-call lifecycle states (mirror Vercel): input-streaming -> input-available
// -> executing -> output-available | error
enum ToolCallState { inputStreaming, inputAvailable, executing, outputAvailable, error }
```

`ToolCallPart` / `ToolResultPart` live in `flutter_ai_core`; this package adds
declaration + execution + (optional) automatic round-tripping
(call → `execute` → resubmit result) when the host opts in.

### Web search & structured actions

- A `WebSearchTool` is just a `ToolSpec` whose `execute` hits a search adapter
  (host-provided: Tavily, Brave, SerpAPI, custom). Results map to `SourcePart`s
  so `AiSources` can render citations.
- "Structured actions" (e.g. "create calendar event") are tools whose result is a
  typed payload the host handles — UI shows the `AiToolInvocation` card.

### Parallel-call visualization contract

- Parallel tool calls are grouped by the UI into a **vertically stacked list of
  collapsible `AiToolInvocation` cards** (`AiToolGroup`). Each shows its own
  args + result independently. This package defines the grouping key
  (`messageId` + ordering); rendering lives in `elements`.

### Malformed-args handling

- Tool args arrive as partial JSON deltas. The core `MessageProcessor` parses
  tolerantly and only emits `ToolCallReady` on valid JSON. If validation against
  `parametersSchema` fails, that tool node halts and a scoped validation error is
  emitted to the transport — the app never crashes, other tools keep streaming.

### Example

```dart
final weatherTool = ToolSpec(
  name: 'get_weather',
  description: 'Get current weather for a city',
  parametersSchema: {
    'type': 'object',
    'properties': {'city': {'type': 'string'}},
    'required': ['city'],
  },
  execute: (args) => weatherApi.fetch(args['city'] as String),
);

UseChatController(provider: provider, tools: [weatherTool]);
```

### MVP vs. future

- **MVP:** `ToolSpec`, lifecycle states, manual result resubmission, web-search
  adapter interface.
- **Future:** automatic multi-step tool loops, schema validation helpers,
  generative-UI tools (tool returns a `DataPart` → catalog widget).

---

## Part B — Attachments

### Purpose

Models for files/images/audio in messages and the composer, plus preview widgets.
Models live in `flutter_ai_core` (`FilePart`); widgets live in
`flutter_ai_elements` under `src/attachments/` — a self-contained subtree ready to
become `flutter_ai_attachments` if it grows.

### Problems solved

- Attach images/files/audio to a prompt; preview them in the composer and in
  message bubbles.
- A consistent `FilePart` (mediaType + url *or* bytes + name) across providers.

### Non-goals

- **No document extraction / parsing** (PDF→text, OCR) on the client — that
  freezes the UI thread. Delegate to backend workflows or ingest adapters.
- No file storage/upload service — host provides upload; we carry the result.

### Core API

```dart
// In flutter_ai_core
class FilePart extends AiPart {
  final String mediaType;        // e.g. image/png, application/pdf, audio/m4a
  final Uri? url;                // remote/hosted
  final Uint8List? bytes;        // inline
  final String? name;
}

// In elements
AiAttachmentPreview(part: filePart);           // thumbnail / file chip / audio tile
AiPromptInput(allowAttachments: true, acceptedTypes: [...]);
```

- Picking files is host-driven (`file_picker` / `image_picker`); the composer
  exposes an `onPickAttachment` hook rather than hard-depending on a picker.

### MVP vs. future

- **MVP:** image + generic file chips in composer and messages.
- **Future:** audio attachment playback tile, inline image lightbox, drag-drop on
  desktop/web, split into `flutter_ai_attachments`.

### Open questions

- Do we provide a default picker integration, or stay picker-agnostic? (Lean:
  agnostic core, optional `flutter_ai_attachments` adds a default.)
- Max inline byte size before forcing host upload?

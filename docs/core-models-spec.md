# Spec: `flutter_ai_core`

## Purpose

The shared, dependency-free contract layer: message/conversation models, the
message-parts model, the streaming `MessageProcessor`, and the core interfaces
(`LlmProvider`, `TextRenderer`). Everything else in the family builds on these
types.

## Target users

- Every other `flutter_ai` package.
- Provider authors who need the message/stream contract without a UI or a state
  manager.

## Problems solved

- A single, stable vocabulary for AI messages across providers and UIs.
- Jank-free streaming via frame-aligned, granular mutation.
- Zero version-conflict risk for downstream apps (no build_runner / codegen).

## Non-goals

- No Flutter, no widgets, no rendering.
- No HTTP / transport (that's `flutter_ai_client`).
- No token-budget pruning, no RAG, no document parsing.
- No code generation. Manual serialization only.

## Dependencies

- `dart:core`, `dart:convert`. **Nothing else.**

## Core models

```dart
enum AiRole { system, user, assistant, tool }

/// A message is an ordered list of typed parts (Vercel-style "parts" model).
class AiMessage {
  final String id;
  final AiRole role;
  final List<AiPart> parts;
  final AiMessageStatus status;   // pending | streaming | complete | error
  final FinishReason? finishReason;
  final DateTime? createdAt;

  const AiMessage({ required this.id, required this.role, required this.parts,
    this.status = AiMessageStatus.complete, this.finishReason, this.createdAt });

  AiMessage copyWith({ ... });
  factory AiMessage.fromJson(Map<String, dynamic> json) { ... } // manual
  Map<String, dynamic> toJson() { ... }                          // manual
  // hand-written == / hashCode
}

/// Sealed-style part hierarchy (Dart sealed class).
sealed class AiPart {}
class TextPart        extends AiPart { final String text; }
class ReasoningPart   extends AiPart { final String text; }      // chain-of-thought
class ToolCallPart    extends AiPart { final String toolCallId, toolName;
                                       final Map<String, dynamic> args;
                                       final ToolCallState state; } // input-streaming|complete|...
class ToolResultPart  extends AiPart { final String toolCallId; final Object? result;
                                       final bool isError; }
class FilePart        extends AiPart { final String mediaType; final Uri? url;
                                       final Uint8List? bytes; final String? name; }
class SourcePart      extends AiPart { final Uri url; final String? title; } // citations
class DataPart        extends AiPart { final String type; final Map<String,dynamic> data; } // generative-UI node

class AiConversation {
  final String id;
  final List<AiMessage> messages;   // FULL history retained (UI scrolls back)
  AiConversation copyWith({ ... });
}

enum FinishReason { stop, length, toolCalls, contentFilter, error }
```

> **Memory note:** the conversation keeps the *complete* message array. Pruning
> for token limits is a server/provider responsibility — never done here.

## Streaming: `MessageProcessor` + mutators

Ported in spirit from genui's A2UI streaming. A pure-Dart processor consumes a
provider's chunk stream and emits **granular mutations**, not whole new trees.

```dart
/// Provider-neutral stream events.
sealed class AiStreamEvent {}
class TextDelta       extends AiStreamEvent { final String messageId, delta; }
class ReasoningDelta  extends AiStreamEvent { final String messageId, delta; }
class ToolCallDelta   extends AiStreamEvent { final String toolCallId, argsJsonDelta; }
class ToolCallReady   extends AiStreamEvent { final ToolCallPart call; }
class PartAdded       extends AiStreamEvent { final String messageId; final AiPart part; }
class MessageFinished extends AiStreamEvent { final String messageId; final FinishReason reason; }
class StreamError     extends AiStreamEvent { final Object error; final String? messageId; }

class MessageProcessor {
  /// Apply an event to current state, returning the *minimal* set of changed
  /// node ids so the UI can rebuild only those nodes.
  MutationResult apply(AiStreamEvent event);
}

class MutationResult {
  final AiConversation conversation;
  final Set<String> changedNodeIds;   // drives targeted rebuilds
}
```

### Performance contract

- **Frame-aligned batching:** consumers (the controller/UI) coalesce mutations and
  flush on the scheduler frame boundary or `scheduleMicrotask`. The processor
  itself is synchronous and side-effect-free; batching is the consumer's job, so
  core stays Flutter-free.
- **Partial JSON for tool args:** `ToolCallDelta` carries incremental JSON; the
  processor maintains a tolerant incremental parser and only surfaces a validated
  `ToolCallReady` once arguments parse. Malformed JSON halts *that* tool node and
  emits `StreamError` scoped to its `messageId`/`toolCallId` — it never throws
  into the app.

## Core interfaces (declarations only)

```dart
abstract interface class LlmProvider {
  Stream<AiStreamEvent> send(AiConversation conversation, {
    List<ToolSpec> tools, AiRequestOptions? options });
}

abstract interface class TextRenderer {            // implemented in UI packages
  // declared here so core types can reference it without a Flutter dep
}
```

## Example usage

```dart
final processor = MessageProcessor(seed: conversation);
await for (final event in provider.send(conversation, tools: tools)) {
  final result = processor.apply(event);
  // host batches result.changedNodeIds to the frame boundary
}
```

## Extensibility points

- New `AiPart` subtypes (sealed, so exhaustive `switch` keeps callers honest).
- Custom `AiStreamEvent`s for provider-specific signals.
- `TextRenderer` interface lets UIs swap markdown engines.

## MVP vs. future

- **MVP:** models, parts, `MessageProcessor`, text/reasoning/tool deltas, manual
  JSON, tolerant tool-arg parser.
- **Future:** `DataPart`/generative-UI catalog binding helpers, multi-modal parts
  (audio/video), conversation persistence helpers (still storage-agnostic).

## Open questions

- Should `MutationResult` expose a typed patch list (op/path/value) for
  fine-grained diffing, or is `changedNodeIds` enough?
- Do we model "annotations"/metadata as a first-class part or a side map?

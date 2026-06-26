/// Dependency-free Dart foundation for AI chat experiences.
///
/// `flutter_ai_core` defines the shared vocabulary the rest of the `flutter_ai`
/// family builds on:
///
///  * **Models** — `AiConversation`, `AiMessage`, and the sealed `AiPart`
///    hierarchy (`TextPart`, `ReasoningPart`, `ToolCallPart`, `ToolResultPart`,
///    `FilePart`, `SourcePart`, `DataPart`).
///  * **Streaming** — the sealed `AiStreamEvent` set and a `MessageProcessor`
///    that folds events into state with granular `MutationResult`s, plus a
///    tolerant `JsonAccumulator` for partial tool-call arguments.
///  * **Contracts** — `LlmProvider` for provider abstraction and `TextRenderer`
///    for pluggable text rendering, with `AiRequestOptions` and `ToolDefinition`.
///
/// It depends only on `dart:core` and `dart:convert` — no Flutter, no code
/// generation — so downstream apps never face build-tool or version conflicts.
library;

export 'src/models/ai_conversation.dart';
export 'src/models/ai_message.dart';
export 'src/models/ai_part.dart';
export 'src/models/ai_role.dart';
export 'src/models/finish_reason.dart';
export 'src/models/tool_call_state.dart';
export 'src/models/tool_definition.dart';
export 'src/provider/ai_request_options.dart';
export 'src/provider/llm_provider.dart';
export 'src/rendering/text_renderer.dart';
export 'src/streaming/ai_stream_event.dart';
export 'src/streaming/json_accumulator.dart';
export 'src/streaming/message_processor.dart';
export 'src/streaming/mutation_result.dart';

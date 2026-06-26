import 'package:flutter_ai_core/src/models/ai_conversation.dart';
import 'package:flutter_ai_core/src/models/tool_definition.dart';
import 'package:flutter_ai_core/src/provider/ai_request_options.dart';
import 'package:flutter_ai_core/src/streaming/ai_stream_event.dart';

/// The contract every model backend implements: turn a conversation into a
/// stream of incremental [AiStreamEvent]s.
///
/// This is the single seam that makes the ecosystem provider-agnostic. A
/// concrete provider (OpenAI, Anthropic, Gemini, an on-device model, or a
/// custom backend) maps its native protocol onto these events; everything above
/// it — controllers, UI — is written once against this interface.
///
/// Implementations should:
///
///  * emit a terminal [MessageFinished] (or [StreamErrorEvent]) for each assistant
///    message they produce, so consumers can finalize state and accessibility;
///  * surface failures as a [StreamErrorEvent] event where possible, reserving thrown
///    exceptions for programming errors and unrecoverable transport faults;
///  * stop work promptly when the returned stream's subscription is cancelled.
abstract interface class LlmProvider {
  /// Generates a response to [conversation].
  ///
  /// [tools] advertises the tools the model may call; `null` or empty means
  /// none. [options] carries model selection and sampling parameters; `null`
  /// means provider defaults. The returned stream is single-subscription;
  /// cancelling its subscription must cancel the request.
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  });
}

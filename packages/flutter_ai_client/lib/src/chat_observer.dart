import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Observes the agent lifecycle of a `UseChatController` for tracing, metrics,
/// and logging.
///
/// The callbacks are shaped after the OpenTelemetry **GenAI semantic
/// conventions** — a turn wraps one or more model requests, each of which
/// finishes with a reason and token [AiUsage], with tool executions in between
/// — but this carries **no OpenTelemetry dependency**. Map the callbacks onto
/// your own tracer, span exporter, or analytics sink. Stamp your own timing on
/// receipt; the controller does not impose a clock.
///
/// Every method has a no-op default, so subclasses override only what they
/// need. Callbacks are invoked synchronously from the controller; keep them
/// cheap (enqueue, don't block).
abstract class ChatObserver {
  /// Const constructor for subclasses.
  const ChatObserver();

  /// A turn began: the user submitted, regenerated, retried, or edited.
  /// [conversation] is the transcript at that moment.
  void onTurnStart(AiConversation conversation) {}

  /// A model request is about to be dispatched. [step] is 1-based within the
  /// turn (it increments for each tool-loop re-prompt).
  void onModelRequest(int step) {}

  /// A model response finished streaming cleanly for [step]. [usage] and
  /// [finishReason] are provided when the provider reported them.
  void onModelResponse({
    required int step,
    AiUsage? usage,
    FinishReason? finishReason,
  }) {}

  /// A batch of tool [calls] is about to be executed by the agent loop.
  void onToolCalls(List<ToolCallPart> calls) {}

  /// Tool [results] were produced (executed results plus any validation-error
  /// results) and fed back to the model.
  void onToolResults(List<ToolResultPart> results) {}

  /// The turn failed with [error] (and [stackTrace] when available). Followed
  /// by [onTurnEnd].
  void onError(Object error, StackTrace? stackTrace) {}

  /// The turn ended — success, stop, or error. [totalUsage] is the summed usage
  /// across the whole conversation, or null if none was reported.
  void onTurnEnd({AiUsage? totalUsage}) {}
}

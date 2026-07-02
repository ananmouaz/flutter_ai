import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_client/src/chat_observer.dart';
import 'package:flutter_ai_client/src/chat_status.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Drives a chat conversation against any [LlmProvider], exposing state as a
/// [Listenable] (this class is a [ChangeNotifier]).
///
/// This is the Dart analogue of the web `useChat` hook. It is deliberately
/// **un-opinionated about state management**: bind it with `ListenableBuilder`,
/// or adapt it to Bloc / Riverpod / Provider — the controller imposes nothing.
/// The raw [events] stream is available as an escape hatch for custom state
/// layers.
///
/// ### Streaming performance
///
/// Incoming events are folded by an internal [MessageProcessor], and
/// [notifyListeners] is **coalesced**: many events arriving in one turn trigger
/// a single notification. The coalescing strategy is injectable via `scheduler`
/// (defaulting to [scheduleMicrotask]); combined with Flutter's per-frame
/// rebuild pipeline this keeps high token rates from dropping frames. A host
/// that wants strict frame alignment can pass a scheduler backed by
/// `SchedulerBinding.addPostFrameCallback`.
///
/// ### History
///
/// The full message history is retained so the user can scroll the whole
/// session; trimming for token budgets is a provider/server concern, not the
/// controller's.
class UseChatController extends ChangeNotifier {
  /// Creates a controller bound to [provider].
  ///
  /// [initial] seeds the conversation. [tools] and [options] are forwarded to
  /// the provider on every request. [scheduler] customizes notification
  /// batching (defaults to [scheduleMicrotask]). [idGenerator] supplies ids for
  /// locally-created user messages (defaults to a sequential generator).
  ///
  /// ### Agent loop
  ///
  /// Provide [onToolCalls] to turn the controller into an automatic agent: when
  /// a model turn ends with tool calls that have no results yet, the controller
  /// invokes [onToolCalls], appends the returned [ToolResultPart]s, and
  /// re-prompts the model — repeating until a turn has no pending tool calls or
  /// [maxSteps] model calls have run. Without [onToolCalls] the behavior is
  /// unchanged: the turn ends with the tool calls and the host drives execution
  /// manually via [addToolResults].
  ///
  /// [onToolCalls] receives an [AiToolCallSignal] as its second argument. The
  /// controller cancels it if the turn is stopped, replaced, or disposed while
  /// the executor is still running, so a long-running tool can abort in-flight
  /// work (e.g. cancel an HTTP request via [AiToolCallSignal.whenCancelled])
  /// instead of running to completion only to have its result discarded.
  ///
  /// ### Tool-argument validation
  ///
  /// When [validateToolArgs] is true (the default) and a tool's
  /// [ToolDefinition.parametersSchema] is non-empty, the controller validates
  /// each model-produced call's arguments against that schema *before* running
  /// [onToolCalls]. A call whose args violate the schema is not executed;
  /// instead an error [ToolResultPart] describing the violations is fed back to
  /// the model, which then gets a chance to correct itself (still bounded by
  /// [maxSteps]). Tools with no schema, and calls for unknown tool names, skip
  /// validation.
  ///
  /// ### Runaway-loop guard
  ///
  /// [maxIdenticalToolCalls] (0 = off, the default) halts the agent loop if the
  /// model requests the same tool call — identical name **and** arguments —
  /// after it has already run that many times in the turn. Instead of looping
  /// up to [maxSteps] and spending tokens, the turn ends with [error] set to an
  /// [AgentLoopException]. Complements [tokenBudget], which caps total tokens.
  ///
  /// ### Observability
  ///
  /// Pass a [ChatObserver] to receive lifecycle callbacks (turn start, each
  /// model request, response + token usage, tool calls/results, errors, turn
  /// end) shaped after the OpenTelemetry GenAI semantic conventions — with no
  /// OpenTelemetry dependency. Map them onto your own tracer or analytics sink.
  ///
  /// ### History trimming
  ///
  /// [trimHistory], when provided, maps the full conversation to the (smaller)
  /// conversation actually sent to the provider on each request. The stored
  /// transcript is never trimmed — [conversation]/[messages] still return
  /// everything — so the UI keeps the full history while requests stay within a
  /// token budget. See `keepLastMessages` and `trimToApproxTokenBudget` for
  /// ready-made strategies.
  UseChatController({
    required LlmProvider provider,
    AiConversation? initial,
    List<ToolDefinition> tools = const [],
    AiRequestOptions? options,
    Future<List<ToolResultPart>> Function(
      List<ToolCallPart> calls,
      AiToolCallSignal signal,
    )? onToolCalls,
    int maxSteps = 8,
    int maxBranches = 20,
    int? tokenBudget,
    int maxIdenticalToolCalls = 0,
    bool validateToolArgs = true,
    ChatObserver? observer,
    AiConversation Function(AiConversation conversation)? trimHistory,
    void Function(VoidCallback callback)? scheduler,
    String Function()? idGenerator,
  })  : assert(maxSteps >= 1, 'maxSteps must be at least 1'),
        assert(maxBranches >= 1, 'maxBranches must be at least 1'),
        assert(maxIdenticalToolCalls >= 0,
            'maxIdenticalToolCalls must be >= 0 (0 disables loop detection)'),
        _provider = provider,
        _tools = List.unmodifiable(tools),
        _options = options,
        _onToolCalls = onToolCalls,
        _maxSteps = maxSteps,
        _maxBranches = maxBranches,
        _tokenBudget = tokenBudget,
        _maxIdenticalToolCalls = maxIdenticalToolCalls,
        _observer = observer,
        _validateToolArgs = validateToolArgs,
        _trimHistory = trimHistory,
        _scheduler = scheduler ?? scheduleMicrotask,
        _newId = idGenerator ?? _sequentialIdGenerator(),
        _processor = MessageProcessor(conversation: initial);

  final MessageProcessor _processor;
  final void Function(VoidCallback callback) _scheduler;
  final String Function() _newId;
  final Future<List<ToolResultPart>> Function(
    List<ToolCallPart>,
    AiToolCallSignal,
  )? _onToolCalls;
  // The signal for the tool batch currently executing, cancelled if the turn is
  // torn down (stop/replace/dispose) while the executor runs.
  AiToolCallSignal? _activeToolSignal;
  final int _maxSteps;
  final int _maxBranches;
  final bool _validateToolArgs;
  final AiConversation Function(AiConversation)? _trimHistory;
  final int? _tokenBudget; // stop the agent loop once cumulative tokens exceed
  // Halt the agent loop if the model requests the same (toolName, args) call
  // this many times in one turn — a runaway-loop guard. 0 disables it.
  final int _maxIdenticalToolCalls;
  // Per-turn count of executed tool-call signatures, for loop detection.
  final Map<String, int> _toolCallCounts = {};
  // Optional lifecycle observer for tracing/metrics.
  final ChatObserver? _observer;
  // The finish reason from the most recent MessageFinished, for the observer.
  FinishReason? _lastFinishReason;
  final StreamController<AiStreamEvent> _events =
      StreamController<AiStreamEvent>.broadcast();

  LlmProvider _provider;
  List<ToolDefinition> _tools;
  AiRequestOptions? _options;

  // Regeneration branches for the latest turn: each version is the slice of
  // messages after the last user message. `regenerate` appends a version;
  // navigating swaps which one is shown.
  List<List<AiMessage>> _branches = [];
  int _branchIndex = 0;
  _Capture _capture = _Capture.reset;

  ChatStatus _status = ChatStatus.idle;
  Object? _error;
  StackTrace? _stackTrace;
  StreamSubscription<AiStreamEvent>? _subscription;
  Completer<void>? _turn;
  int _step = 0; // model calls executed so far in the current agent turn
  int _turnSeq = 0; // bumped whenever a turn is torn down/replaced
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// The full conversation transcript.
  AiConversation get conversation => _processor.conversation;

  /// The messages in the conversation.
  List<AiMessage> get messages => _processor.conversation.messages;

  /// The current turn status.
  ChatStatus get status => _status;

  /// The error from the last failed turn, or `null`.
  Object? get error => _error;

  /// The stack trace captured alongside [error], or `null`.
  StackTrace? get stackTrace => _stackTrace;

  /// How many regenerated versions exist for the latest turn (1 = no
  /// alternatives). Drive an `AiBranch` with this and [branchIndex].
  int get branchCount => _branches.length;

  /// The 0-based index of the version currently shown for the latest turn.
  int get branchIndex => _branchIndex;

  /// The summed token usage across every message in the conversation that
  /// reported it, or `null` if none did. Feed an `AiContextMeter` or estimate
  /// cost with [AiUsage.estimateCost].
  AiUsage? get totalUsage {
    AiUsage? total;
    for (final message in _processor.conversation.messages) {
      final usage = message.usage;
      if (usage != null) total = total == null ? usage : total + usage;
    }
    return total;
  }

  /// A broadcast stream of every event applied to the conversation.
  ///
  /// An escape hatch for hosts that want to react to raw events (analytics,
  /// custom state). Most callers should rely on [conversation] plus listener
  /// notifications instead.
  Stream<AiStreamEvent> get events => _events.stream;

  /// Sends a user message composed of [text] and optional [attachments].
  ///
  /// Returns a future that completes when the resulting turn finishes (or is
  /// stopped). A no-op if [text] is empty and there are no [attachments].
  Future<void> sendText(
    String text, {
    List<AiPart> attachments = const [],
  }) {
    final parts = <AiPart>[
      ...attachments,
      if (text.isNotEmpty) TextPart(text),
    ];
    if (parts.isEmpty) return Future<void>.value();
    return submit(AiMessage(id: _newId(), role: AiRole.user, parts: parts));
  }

  /// Appends [userMessage] optimistically and streams the model's response.
  ///
  /// The append happens **synchronously** before the request is dispatched, so
  /// the user's message paints immediately. Any in-flight turn is cancelled
  /// first. Returns a future that completes when the new turn finishes, errors,
  /// or is stopped.
  Future<void> submit(AiMessage userMessage) {
    _stopActiveStream();
    _error = null;
    _stackTrace = null;
    _capture = _Capture.reset; // a new user turn starts a fresh branch set
    _step = 0;
    _toolCallCounts.clear();
    _processor.reset(_processor.conversation.append(userMessage));
    _status = ChatStatus.submitted;
    _scheduleNotify();
    return _beginTurn();
  }

  /// Re-runs the model from the most recent user message, discarding everything
  /// after it. A no-op if there is no user message.
  Future<void> regenerate() {
    final all = _processor.conversation.messages;
    final lastUser = all.lastIndexWhere((m) => m.role == AiRole.user);
    if (lastUser == -1) return Future<void>.value();
    _stopActiveStream();
    _error = null;
    _stackTrace = null;
    _capture = _Capture.append; // keep the prior version, add a new one
    _step = 0;
    _toolCallCounts.clear();
    _processor.reset(
      _processor.conversation.copyWith(messages: all.sublist(0, lastUser + 1)),
    );
    _status = ChatStatus.submitted;
    _scheduleNotify();
    return _beginTurn();
  }

  /// Edits the user message [messageId] to [text] — keeping any non-text parts
  /// such as attachments — discards every message after it, and re-runs the
  /// model from that point. A no-op if [messageId] is not a user message in the
  /// transcript, or if the edit would leave the message empty.
  ///
  /// A reworded prompt starts a fresh branch set (the previous answer was to a
  /// different question), like editing a sent message in a typical chat UI.
  Future<void> editMessage(String messageId, String text) {
    final all = _processor.conversation.messages;
    final index = all.indexWhere((m) => m.id == messageId);
    if (index == -1 || all[index].role != AiRole.user) {
      return Future<void>.value();
    }
    final original = all[index];
    // Replace the first text part in place (preserving attachment order); drop
    // any other text parts. Append the new text if the message had none.
    final parts = <AiPart>[];
    var replaced = false;
    for (final part in original.parts) {
      if (part is TextPart) {
        if (!replaced && text.isNotEmpty) {
          parts.add(TextPart(text));
          replaced = true;
        }
      } else {
        parts.add(part);
      }
    }
    if (!replaced && text.isNotEmpty) parts.add(TextPart(text));
    if (parts.isEmpty) return Future<void>.value();

    _stopActiveStream();
    _error = null;
    _stackTrace = null;
    _capture = _Capture.reset;
    _step = 0;
    _toolCallCounts.clear();
    _processor.reset(
      _processor.conversation.copyWith(
        messages: [
          ...all.sublist(0, index),
          original.copyWith(parts: parts, status: AiMessageStatus.complete),
        ],
      ),
    );
    _status = ChatStatus.submitted;
    _scheduleNotify();
    return _beginTurn();
  }

  /// Edits the most recent user message to [text] and re-runs from it. A no-op
  /// if there is no user message. See [editMessage].
  Future<void> editLastUserMessage(String text) {
    final lastUser = _lastUserIndex();
    if (lastUser == -1) return Future<void>.value();
    return editMessage(_processor.conversation.messages[lastUser].id, text);
  }

  /// Switches the latest turn to regenerated version [index] (0-based). A no-op
  /// out of range, while a turn is in flight, or if already showing it.
  void selectBranch(int index) {
    if (index < 0 || index >= _branches.length || index == _branchIndex) return;
    // Never switch branches while a turn is in flight — including the agent
    // loop's tool-execution phase, whose live continuation would otherwise
    // append tool results onto the swapped transcript and corrupt it.
    if (_turn != null) return;
    final lastUser = _lastUserIndex();
    if (lastUser == -1) return;
    final head = _processor.conversation.messages.sublist(0, lastUser + 1);
    _branchIndex = index;
    _processor.reset(
      _processor.conversation
          .copyWith(messages: [...head, ..._branches[index]]),
    );
    _scheduleNotify();
  }

  /// Appends tool [results] as an [AiRole.tool] message and streams the model's
  /// continuation — call this after executing the tool calls the model
  /// requested. A no-op if [results] is empty.
  ///
  /// Every [ToolCallPart] in the preceding assistant message should have a
  /// matching [ToolResultPart] here before continuing, as providers require a
  /// result per call. When an `onToolCalls` executor is configured the
  /// controller calls this for you (the agent loop); use it directly only for
  /// manual tool handling.
  Future<void> addToolResults(List<ToolResultPart> results) {
    if (results.isEmpty) return Future<void>.value();
    _stopActiveStream();
    _error = null;
    _stackTrace = null;
    _capture = _Capture.update; // continuation of the current version's turn
    _processor.reset(
      _processor.conversation.append(
        AiMessage(
          id: _newId(),
          role: AiRole.tool,
          parts: List<AiPart>.of(results),
        ),
      ),
    );
    _status = ChatStatus.submitted;
    _scheduleNotify();
    return _beginTurn();
  }

  /// Cancels the in-flight turn, finalizing the streaming message as stopped.
  void stop() {
    _stopActiveStream();
    final last = _processor.conversation.lastMessage;
    if (last != null && last.status == AiMessageStatus.streaming) {
      _processor.apply(
        MessageFinished(messageId: last.id, reason: FinishReason.stop),
      );
    }
    _status = ChatStatus.idle;
    _scheduleNotify();
  }

  /// Switches the active provider. Does not affect the current transcript or
  /// interrupt an in-flight turn.
  void setProvider(LlmProvider provider) {
    _provider = provider;
    _scheduleNotify();
  }

  /// Replaces the request options applied to subsequent turns (for example, to
  /// change the model).
  void setOptions(AiRequestOptions? options) {
    _options = options;
    _scheduleNotify();
  }

  /// Replaces the tools advertised to the provider on subsequent turns.
  void setTools(List<ToolDefinition> tools) {
    _tools = List.unmodifiable(tools);
    _scheduleNotify();
  }

  /// Clears the conversation and cancels any in-flight turn.
  void clear() {
    _stopActiveStream();
    _processor.reset(AiConversation.empty(_processor.conversation.id));
    _error = null;
    _stackTrace = null;
    _status = ChatStatus.idle;
    _branches = [];
    _branchIndex = 0;
    _capture = _Capture.reset;
    _scheduleNotify();
  }

  int _lastUserIndex() => _processor.conversation.messages
      .lastIndexWhere((m) => m.role == AiRole.user);

  /// Snapshots the post-user-message tail as the current branch version. Called
  /// on each successful turn completion; the [_capture] mode decides whether to
  /// start fresh, append a new version, or update the in-progress one.
  void _captureBranch() {
    final lastUser = _lastUserIndex();
    if (lastUser == -1) return;
    final tail = _processor.conversation.messages.sublist(lastUser + 1);
    if (tail.isEmpty) return;
    switch (_capture) {
      case _Capture.reset:
        _branches = [tail];
        _branchIndex = 0;
      case _Capture.append:
        _branches.add(tail);
        // Cap retained regenerations so a long-running chat can't grow without
        // bound; drop the oldest version(s) and keep the index aligned.
        while (_branches.length > _maxBranches) {
          _branches.removeAt(0);
        }
        _branchIndex = _branches.length - 1;
      case _Capture.update:
        if (_branches.isEmpty) {
          _branches = [tail];
          _branchIndex = 0;
        } else {
          _branches[_branchIndex] = tail;
        }
    }
    // Further completions in the same turn (tool rounds) update this version.
    _capture = _Capture.update;
  }

  /// Opens a fresh turn future and dispatches the first model call. The future
  /// completes when the whole turn ends — including any automatic agent-loop
  /// continuations.
  Future<void> _beginTurn() {
    final completer = Completer<void>();
    _turn = completer;
    _observer?.onTurnStart(_processor.conversation);
    _dispatch();
    return completer.future;
  }

  /// Subscribes to one provider stream, folding events into the conversation.
  void _dispatch() {
    _step++; // one model call
    _observer?.onModelRequest(_step);
    // Capture the turn this subscription belongs to. A late event from a
    // cancelled stream (a microtask already queued when the turn was torn down)
    // must not mutate the conversation or leak onto the events stream after a
    // new turn started.
    final seq = _turnSeq;
    // The provider sees the (optionally trimmed) conversation; the stored
    // transcript is never trimmed.
    final outgoing =
        _trimHistory?.call(_processor.conversation) ?? _processor.conversation;
    _subscription =
        _provider.send(outgoing, tools: _tools, options: _options).listen(
      (event) {
        if (_disposed || seq != _turnSeq) return;
        _processor.apply(event);
        if (!_events.isClosed) _events.add(event);
        if (event is MessageFinished) _lastFinishReason = event.reason;
        // A message-scoped error event is fatal: record the error and tear the
        // turn down so a misbehaving provider cannot keep mutating the
        // conversation past the failure. A tool-scoped error is left to the
        // tool result instead and streaming continues.
        if (event is StreamErrorEvent && event.toolCallId == null) {
          _error = event.error;
          _status = ChatStatus.error;
          _observer?.onError(event.error, null);
          final sub = _subscription;
          _subscription = null;
          if (sub != null) unawaited(sub.cancel());
          _completeTurn();
          _scheduleNotify();
          return;
        } else if (_status == ChatStatus.submitted) {
          _status = ChatStatus.streaming;
        }
        _scheduleNotify();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_disposed || seq != _turnSeq) return;
        _error = error;
        _stackTrace = stackTrace;
        _status = ChatStatus.error;
        _observer?.onError(error, stackTrace);
        final last = _processor.conversation.lastMessage;
        if (last != null && last.status == AiMessageStatus.streaming) {
          _processor.apply(
            StreamErrorEvent(error: error, messageId: last.id),
          );
        }
        _subscription = null;
        _completeTurn();
        _scheduleNotify();
      },
      onDone: () {
        if (_disposed || seq != _turnSeq) return;
        _onStreamDone();
      },
      cancelOnError: true,
    );
  }

  /// A provider stream completed cleanly. Captures the branch, then either runs
  /// the agent loop (execute pending tool calls and re-prompt) or ends the turn.
  void _onStreamDone() {
    _subscription = null;
    if (_status == ChatStatus.error) {
      _completeTurn();
      _scheduleNotify();
      return;
    }
    _captureBranch();
    _observer?.onModelResponse(
      step: _step,
      usage: _processor.conversation.lastMessage?.usage,
      finishReason: _lastFinishReason,
    );

    final pending = _pendingToolCalls();
    // Runaway-loop guard: if the model keeps requesting a tool call it has
    // already run `maxIdenticalToolCalls` times with identical args, halt with
    // a typed error instead of looping (and burning tokens) to `maxSteps`.
    if (_onToolCalls != null &&
        pending.isNotEmpty &&
        _maxIdenticalToolCalls > 0) {
      for (final call in pending) {
        if ((_toolCallCounts[_toolCallSignature(call)] ?? 0) >=
            _maxIdenticalToolCalls) {
          _error = AgentLoopException(call.toolName, _maxIdenticalToolCalls);
          _status = ChatStatus.error;
          _completeTurn();
          _scheduleNotify();
          return;
        }
      }
    }
    final overBudget = _tokenBudget != null &&
        (totalUsage?.resolvedTotal ?? 0) >= _tokenBudget;
    if (_onToolCalls != null &&
        pending.isNotEmpty &&
        _step < _maxSteps &&
        !overBudget) {
      // The turn stays in flight while the tool executor runs; keep the
      // controller busy so UIs don't re-enable input and stores don't persist a
      // mid-turn transcript with unanswered tool calls (see selectBranch).
      _status = ChatStatus.executingTools;
      _scheduleNotify();
      unawaited(_continueWithTools(pending, _turn));
      return;
    }
    _status = ChatStatus.idle;
    _completeTurn();
    _scheduleNotify();
  }

  /// Runs [_onToolCalls] for [calls] and feeds the results back into the model,
  /// continuing the same [turn]. Aborts silently if the turn was stopped or
  /// replaced while the executor ran.
  Future<void> _continueWithTools(
    List<ToolCallPart> calls,
    Completer<void>? turn,
  ) async {
    // Split off calls whose arguments violate the tool's parametersSchema:
    // those are answered with an error result (so the model can retry) instead
    // of being handed to the executor.
    _observer?.onToolCalls(calls);
    final (valid, validationErrors) = _validateToolArgs
        ? _splitInvalidCalls(calls)
        : (calls, const <ToolResultPart>[]);

    // Record what we're about to run so the loop guard in _onStreamDone can spot
    // the model re-requesting an identical call.
    if (_maxIdenticalToolCalls > 0) {
      for (final call in valid) {
        final sig = _toolCallSignature(call);
        _toolCallCounts[sig] = (_toolCallCounts[sig] ?? 0) + 1;
      }
    }

    List<ToolResultPart> executed = const [];
    if (valid.isNotEmpty) {
      final signal = AiToolCallSignal();
      _activeToolSignal = signal;
      try {
        executed = await _onToolCalls!(valid, signal);
      } catch (error, stackTrace) {
        if (identical(_activeToolSignal, signal)) _activeToolSignal = null;
        if (_disposed || !identical(_turn, turn)) return;
        _error = error;
        _stackTrace = stackTrace;
        _status = ChatStatus.error;
        _observer?.onError(error, stackTrace);
        _completeTurn();
        _scheduleNotify();
        return;
      }
      if (identical(_activeToolSignal, signal)) _activeToolSignal = null;
    }
    if (_disposed || !identical(_turn, turn) || turn == null) return;
    final results = [...validationErrors, ...executed];
    _observer?.onToolResults(results);
    if (results.isEmpty) {
      _status = ChatStatus.idle;
      _completeTurn();
      _scheduleNotify();
      return;
    }
    _capture = _Capture.update;
    _processor.reset(
      _processor.conversation.append(
        AiMessage(
          id: _newId(),
          role: AiRole.tool,
          parts: List<AiPart>.of(results),
        ),
      ),
    );
    _status = ChatStatus.submitted;
    _scheduleNotify();
    _dispatch();
  }

  /// Tool calls in the latest assistant message that have no matching
  /// [ToolResultPart] anywhere in the transcript yet.
  /// A stable identity for a tool call — name plus JSON-encoded args — used to
  /// detect the model re-requesting the exact same call.
  String _toolCallSignature(ToolCallPart call) =>
      '${call.toolName}(${jsonEncode(call.args)})';

  List<ToolCallPart> _pendingToolCalls() {
    final msgs = _processor.conversation.messages;
    final lastAssistant =
        msgs.lastIndexWhere((m) => m.role == AiRole.assistant);
    if (lastAssistant == -1) return const [];
    final calls = msgs[lastAssistant].parts.whereType<ToolCallPart>().toList();
    if (calls.isEmpty) return const [];
    final answered = <String>{
      for (final m in msgs)
        for (final p in m.parts)
          if (p is ToolResultPart) p.toolCallId,
    };
    return calls.where((c) => !answered.contains(c.toolCallId)).toList();
  }

  /// Partitions [calls] into those whose arguments satisfy the matching tool's
  /// [ToolDefinition.parametersSchema] and, for the rest, an error
  /// [ToolResultPart] describing the schema violations. Calls for tools with no
  /// schema, or for tool names not in [_tools], are treated as valid (nothing
  /// to validate against).
  (List<ToolCallPart>, List<ToolResultPart>) _splitInvalidCalls(
    List<ToolCallPart> calls,
  ) {
    final valid = <ToolCallPart>[];
    final errors = <ToolResultPart>[];
    for (final call in calls) {
      Map<String, Object?> schema = const {};
      for (final t in _tools) {
        if (t.name == call.toolName) {
          schema = t.parametersSchema;
          break;
        }
      }
      final violations = schema.isEmpty
          ? const <String>[]
          : validateJsonSchema(call.args, schema);
      if (violations.isEmpty) {
        valid.add(call);
      } else {
        errors.add(
          ToolResultPart(
            toolCallId: call.toolCallId,
            isError: true,
            result: {
              'error': 'invalid_arguments',
              'message': 'Arguments for "${call.toolName}" failed validation. '
                  'Fix them and call the tool again.',
              'violations': violations,
            },
          ),
        );
      }
    }
    return (valid, errors);
  }

  /// Cancels the active subscription (if any) and completes its turn future.
  /// The cancel itself is fire-and-forget — a new stream is started right after,
  /// and `StreamSubscription.cancel` stops delivery immediately.
  void _stopActiveStream() {
    _turnSeq++; // invalidate any in-flight subscription's late events
    // Tell a tool executor running between streams to abort its in-flight work.
    _activeToolSignal?._cancel();
    _activeToolSignal = null;
    final sub = _subscription;
    _subscription = null;
    if (sub != null) unawaited(sub.cancel());
    _completeTurn();
  }

  void _completeTurn() {
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) {
      turn.complete();
      _observer?.onTurnEnd(totalUsage: totalUsage);
    }
  }

  void _scheduleNotify() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    _scheduler(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _activeToolSignal?._cancel();
    _activeToolSignal = null;
    unawaited(_subscription?.cancel());
    _completeTurn();
    unawaited(_events.close());
    super.dispose();
  }

  /// The default message-id generator: a per-controller random prefix plus an
  /// incrementing counter, e.g. `msg-k3f9a1-0`.
  ///
  /// The random prefix is what makes ids collision-resistant. A plain `msg-N`
  /// counter restarts at 0 for every controller, so seeding a controller with a
  /// rehydrated transcript (`ChatStore.load`, which already contains `msg-0…N`)
  /// would make the first new message reuse an existing id — silently corrupting
  /// `messageById`/`replace`/`editMessage` and producing duplicate widget keys.
  /// The prefix also keeps two controllers writing to the same store from
  /// colliding. Pass a custom `idGenerator` to override.
  static String Function() _sequentialIdGenerator() {
    final prefix = (Random().nextInt(1 << 32)).toRadixString(36);
    var n = 0;
    return () => 'msg-$prefix-${n++}';
  }
}

/// How [UseChatController] folds the next completed turn into branch history.
enum _Capture { reset, append, update }

/// A cancellation signal handed to an `onToolCalls` executor as its second
/// argument.
///
/// [UseChatController] cancels it when the turn that launched the tool batch is
/// stopped, replaced (a new turn started), or the controller is disposed while
/// the executor is still running. A long-running tool should observe it and
/// abort its in-flight work — its returned results are discarded once the turn
/// is gone anyway, so honoring cancellation just frees resources sooner.
///
/// Three ways to consume it:
/// ```dart
/// onToolCalls: (calls, signal) async {
///   // 1) Race cancellable I/O against cancellation:
///   final res = await Future.any([httpCall(), signal.whenCancelled]);
///   if (signal.isCancelled) return const [];      // 2) poll before/after work
///   signal.throwIfCancelled();                    // 3) bail between steps
///   ...
/// }
/// ```
class AiToolCallSignal {
  /// Creates an uncancelled signal. The controller constructs one per tool
  /// batch; hosts rarely need to create their own.
  AiToolCallSignal();

  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  /// Whether the owning turn has been cancelled.
  bool get isCancelled => _cancelled;

  /// Completes when the owning turn is cancelled (never with an error). Race it
  /// against cancellable work with [Future.any].
  Future<void> get whenCancelled => _completer.future;

  /// Throws [AiToolCallCancelled] if [isCancelled]. Call between steps of a
  /// long tool to bail out promptly.
  void throwIfCancelled() {
    if (_cancelled) throw const AiToolCallCancelled();
  }

  void _cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Thrown by [AiToolCallSignal.throwIfCancelled] when the turn was cancelled.
class AiToolCallCancelled implements Exception {
  /// Creates the exception.
  const AiToolCallCancelled();

  @override
  String toString() =>
      'AiToolCallCancelled: the tool-call batch was cancelled (the turn was '
      'stopped, replaced, or disposed).';
}

/// Surfaced on [UseChatController.error] when the agent loop is halted because
/// the model requested the same tool call (identical name + args) more than the
/// controller's `maxIdenticalToolCalls` limit — a runaway-loop guard that stops
/// the turn instead of looping (and spending tokens) up to `maxSteps`.
class AgentLoopException implements Exception {
  /// Creates the exception for [toolName] after hitting [limit] identical calls.
  const AgentLoopException(this.toolName, this.limit);

  /// The tool whose repeated identical calls tripped the guard.
  final String toolName;

  /// The configured `maxIdenticalToolCalls` limit that was reached.
  final int limit;

  @override
  String toString() =>
      'AgentLoopException: tool "$toolName" was requested with identical '
      'arguments more than $limit times; halting the agent loop.';
}

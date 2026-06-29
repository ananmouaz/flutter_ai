import 'dart:async';

import 'package:flutter/foundation.dart';
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
  UseChatController({
    required LlmProvider provider,
    AiConversation? initial,
    List<ToolDefinition> tools = const [],
    AiRequestOptions? options,
    void Function(VoidCallback callback)? scheduler,
    String Function()? idGenerator,
  })  : _provider = provider,
        _tools = List.unmodifiable(tools),
        _options = options,
        _scheduler = scheduler ?? scheduleMicrotask,
        _newId = idGenerator ?? _sequentialIdGenerator(),
        _processor = MessageProcessor(conversation: initial);

  final MessageProcessor _processor;
  final void Function(VoidCallback callback) _scheduler;
  final String Function() _newId;
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
    _processor.reset(_processor.conversation.append(userMessage));
    _status = ChatStatus.submitted;
    _scheduleNotify();
    return _startStream();
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
    _processor.reset(
      _processor.conversation.copyWith(messages: all.sublist(0, lastUser + 1)),
    );
    _status = ChatStatus.submitted;
    _scheduleNotify();
    return _startStream();
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
    return _startStream();
  }

  /// Edits the most recent user message to [text] and re-runs from it. A no-op
  /// if there is no user message. See [editMessage].
  Future<void> editLastUserMessage(String text) {
    final lastUser = _lastUserIndex();
    if (lastUser == -1) return Future<void>.value();
    return editMessage(_processor.conversation.messages[lastUser].id, text);
  }

  /// Switches the latest turn to regenerated version [index] (0-based). A no-op
  /// out of range, while streaming, or if already showing it.
  void selectBranch(int index) {
    if (index < 0 || index >= _branches.length || index == _branchIndex) return;
    if (_status == ChatStatus.streaming || _status == ChatStatus.submitted) {
      return;
    }
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
  /// result per call.
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
    return _startStream();
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

  Future<void> _startStream() {
    final completer = Completer<void>();
    _turn = completer;
    _subscription = _provider
        .send(_processor.conversation, tools: _tools, options: _options)
        .listen(
      (event) {
        _processor.apply(event);
        if (!_events.isClosed) _events.add(event);
        // A message-scoped error event is fatal: record the error and tear the
        // turn down so a misbehaving provider cannot keep mutating the
        // conversation past the failure. A tool-scoped error is left to the
        // tool result instead and streaming continues.
        if (event is StreamErrorEvent && event.toolCallId == null) {
          _error = event.error;
          _status = ChatStatus.error;
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
        _error = error;
        _stackTrace = stackTrace;
        _status = ChatStatus.error;
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
        if (_status != ChatStatus.error) {
          _status = ChatStatus.idle;
          _captureBranch();
        }
        _subscription = null;
        _completeTurn();
        _scheduleNotify();
      },
      cancelOnError: true,
    );
    return completer.future;
  }

  /// Cancels the active subscription (if any) and completes its turn future.
  /// The cancel itself is fire-and-forget — a new stream is started right after,
  /// and `StreamSubscription.cancel` stops delivery immediately.
  void _stopActiveStream() {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) unawaited(sub.cancel());
    _completeTurn();
  }

  void _completeTurn() {
    final turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
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
    unawaited(_subscription?.cancel());
    _completeTurn();
    unawaited(_events.close());
    super.dispose();
  }

  static String Function() _sequentialIdGenerator() {
    var n = 0;
    return () => 'msg-${n++}';
  }
}

/// How [UseChatController] folds the next completed turn into branch history.
enum _Capture { reset, append, update }

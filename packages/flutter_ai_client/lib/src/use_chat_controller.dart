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

  ChatStatus _status = ChatStatus.idle;
  Object? _error;
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
    _processor.reset(
      _processor.conversation.copyWith(messages: all.sublist(0, lastUser + 1)),
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
    _status = ChatStatus.idle;
    _scheduleNotify();
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
        // A message-level error event puts the turn into the error state (a
        // tool-scoped error is left to the tool result instead).
        if (event is StreamErrorEvent && event.toolCallId == null) {
          _error = event.error;
          _status = ChatStatus.error;
        } else if (_status == ChatStatus.submitted) {
          _status = ChatStatus.streaming;
        }
        _scheduleNotify();
      },
      onError: (Object error, StackTrace stackTrace) {
        _error = error;
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
        if (_status != ChatStatus.error) _status = ChatStatus.idle;
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

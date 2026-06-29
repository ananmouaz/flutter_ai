import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_client/src/use_chat_controller.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Persists and restores [AiConversation]s so a chat survives app restarts.
///
/// [UseChatController] keeps history in memory only; implement this against
/// whatever storage you like (a file, `shared_preferences`, SQLite, an HTTP
/// API, …) and pair it with [attachStore] to auto-save, seeding new
/// controllers from [load]:
///
/// ```dart
/// final store = MyChatStore();
/// final controller = UseChatController(
///   provider: provider,
///   initial: await store.load('thread-42'),
/// );
/// final detach = attachStore(controller, store, 'thread-42');
/// // ...later, before controller.dispose():
/// detach();
/// ```
///
/// [AiConversation] (and every [AiMessage]/[AiPart]) is JSON-serializable via
/// `toJson`/`fromJson`, so a minimal store is just an encode/decode around your
/// storage layer.
abstract interface class ChatStore {
  /// Returns the stored conversation for [id], or `null` if none exists.
  Future<AiConversation?> load(String id);

  /// Writes [conversation] for [id], replacing any previous value.
  Future<void> save(String id, AiConversation conversation);
}

/// Auto-saves [controller]'s conversation to [store] under [id] whenever it
/// changes and the turn has settled, coalescing rapid changes over [debounce].
///
/// Returns a disposer that detaches the listener; call it before disposing the
/// controller. If a save is pending when you detach, it is flushed immediately
/// so the latest state is not lost.
///
/// Saves are skipped while a turn is in flight (streaming) — the conversation
/// is persisted once it settles, avoiding a write per streamed frame. Loading
/// is the caller's job: pass `await store.load(id)` as the controller's
/// `initial`.
VoidCallback attachStore(
  UseChatController controller,
  ChatStore store,
  String id, {
  Duration debounce = const Duration(milliseconds: 400),
}) {
  Timer? timer;
  void save() => unawaited(store.save(id, controller.conversation));
  void listener() {
    timer?.cancel();
    timer = Timer(debounce, () {
      // Wait for the turn to settle; the settling notification reschedules us.
      if (controller.status.isBusy) return;
      save();
    });
  }

  controller.addListener(listener);
  return () {
    controller.removeListener(listener);
    if (timer?.isActive ?? false) {
      timer!.cancel();
      save();
    }
  };
}

/// A lightweight summary of a stored conversation, for a thread list / sidebar.
class ChatThread {
  /// Creates a thread summary.
  const ChatThread({required this.id, required this.title, this.updatedAt});

  /// The conversation id (pass to [ChatStore.load]).
  final String id;

  /// A human-readable title (see [autoTitle]).
  final String title;

  /// When the thread was last saved, if tracked. Newest-first ordering.
  final DateTime? updatedAt;
}

/// A [ChatStore] that can also enumerate and delete threads — enough to drive a
/// conversation list / sidebar.
abstract interface class ChatThreadStore implements ChatStore {
  /// All stored threads, newest first.
  Future<List<ChatThread>> listThreads();

  /// Removes the thread [id] (no-op if absent).
  Future<void> delete(String id);
}

/// Derives a short title from a conversation's first user message, falling back
/// to [fallback]. Trims to [maxLength] characters.
String autoTitle(
  AiConversation conversation, {
  String fallback = 'New chat',
  int maxLength = 40,
}) {
  final firstUser = conversation.messages
      .where((m) => m.role == AiRole.user)
      .map((m) => m.text.trim())
      .firstWhere((t) => t.isNotEmpty, orElse: () => '');
  if (firstUser.isEmpty) return fallback;
  final oneLine = firstUser.replaceAll(RegExp(r'\s+'), ' ');
  return oneLine.length <= maxLength
      ? oneLine
      : '${oneLine.substring(0, maxLength).trimRight()}…';
}

/// An in-memory [ChatThreadStore] — handy for demos, tests, and prototyping
/// before wiring real storage. Titles are derived via [autoTitle] on save.
class InMemoryChatThreadStore implements ChatThreadStore {
  final Map<String, AiConversation> _conversations = {};
  final Map<String, ChatThread> _threads = {};

  @override
  Future<AiConversation?> load(String id) async => _conversations[id];

  @override
  Future<void> save(String id, AiConversation conversation) async {
    _conversations[id] = conversation;
    _threads[id] = ChatThread(
      id: id,
      title: autoTitle(conversation),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ChatThread>> listThreads() async {
    final threads = _threads.values.toList();
    threads.sort((a, b) {
      final at = a.updatedAt, bt = b.updatedAt;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at); // newest first
    });
    return threads;
  }

  @override
  Future<void> delete(String id) async {
    _conversations.remove(id);
    _threads.remove(id);
  }
}

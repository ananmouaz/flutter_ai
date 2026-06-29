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

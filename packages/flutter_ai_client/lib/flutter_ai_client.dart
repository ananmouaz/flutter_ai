/// Provider-agnostic chat controller for the `flutter_ai` family.
///
/// Exposes `UseChatController`, a `ChangeNotifier` that wraps any
/// `LlmProvider` from `flutter_ai_core` with optimistic send, cancellation,
/// regeneration, model/provider switching, and frame-batched streaming —
/// without imposing a state-management library.
///
/// Re-exports `flutter_ai_core` so consumers get the model and provider types
/// from a single import.
library;

export 'package:flutter_ai_core/flutter_ai_core.dart';

export 'src/chat_status.dart';
export 'src/chat_store.dart';
export 'src/context_strategy.dart';
export 'src/use_chat_controller.dart';

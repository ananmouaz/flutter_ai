import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_elements/src/widgets/ai_composer.dart';

/// A composer bound to a [UseChatController].
///
/// Sends through [UseChatController.sendText], cancels through
/// [UseChatController.stop], and swaps Send for Stop while a turn is in flight.
class AiPromptInput extends StatelessWidget {
  /// Creates a prompt input bound to [controller].
  const AiPromptInput({
    super.key,
    required this.controller,
    this.hintText = 'Message',
  });

  /// The chat controller to drive.
  final UseChatController controller;

  /// Placeholder text for the empty input.
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AiComposer(
        hintText: hintText,
        isBusy: controller.status.isBusy,
        onStop: controller.stop,
        onSend: (text) => unawaited(controller.sendText(text)),
      ),
    );
  }
}

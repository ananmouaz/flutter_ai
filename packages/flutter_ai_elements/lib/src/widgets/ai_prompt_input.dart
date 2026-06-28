import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_elements/src/widgets/ai_composer.dart';

/// A composer bound to a [UseChatController].
///
/// Stages attachments (via [onPickAttachment]) to send with the next message,
/// offers voice dictation ([onVoice]) and a Live entry point ([onLive]). The
/// model selector lives in the app bar, not here.
class AiPromptInput extends StatefulWidget {
  /// Creates a prompt input bound to [controller].
  const AiPromptInput({
    super.key,
    required this.controller,
    this.hintText = 'Message',
    this.onPickAttachment,
    this.onVoice,
    this.onLive,
  });

  /// The chat controller to drive.
  final UseChatController controller;

  /// Placeholder text for the empty input.
  final String hintText;

  /// Host-provided picker; when non-null an attach (+) button is shown.
  final Future<List<FilePart>> Function()? onPickAttachment;

  /// Voice dictation; when non-null a mic button shows while the field is empty.
  final VoidCallback? onVoice;

  /// Live voice mode; when non-null the main button is Live while the field is
  /// empty (and Send once the user types).
  final VoidCallback? onLive;

  @override
  State<AiPromptInput> createState() => _AiPromptInputState();
}

class _AiPromptInputState extends State<AiPromptInput> {
  final List<FilePart> _attachments = [];

  void _send(String text) {
    final staged = List<FilePart>.of(_attachments);
    setState(_attachments.clear);
    unawaited(widget.controller.sendText(text, attachments: staged));
  }

  Future<void> _pick() async {
    final picked = await widget.onPickAttachment!();
    if (picked.isNotEmpty && mounted) {
      setState(() => _attachments.addAll(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => AiComposer(
        hintText: widget.hintText,
        isBusy: widget.controller.status.isBusy,
        onStop: widget.controller.stop,
        onSend: _send,
        onAttach:
            widget.onPickAttachment == null ? null : () => unawaited(_pick()),
        onVoice: widget.onVoice,
        onLive: widget.onLive,
        attachments: _attachments,
        onRemoveAttachment: (f) => setState(() => _attachments.remove(f)),
      ),
    );
  }
}

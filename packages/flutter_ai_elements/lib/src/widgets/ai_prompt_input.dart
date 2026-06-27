import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_elements/src/widgets/ai_composer.dart';
import 'package:flutter_ai_elements/src/widgets/ai_model_selector.dart';

/// A composer bound to a [UseChatController].
///
/// Beyond text + Send/Stop, it can stage attachments (via [onPickAttachment]),
/// switch models (via [models], wired to `setOptions`), and trigger voice input
/// (via [onVoice]). Staged attachments are sent with the next message.
class AiPromptInput extends StatefulWidget {
  /// Creates a prompt input bound to [controller].
  const AiPromptInput({
    super.key,
    required this.controller,
    this.hintText = 'Message',
    this.onPickAttachment,
    this.onVoice,
    this.models = const [],
  });

  /// The chat controller to drive.
  final UseChatController controller;

  /// Placeholder text for the empty input.
  final String hintText;

  /// Host-provided picker; when non-null an attach (+) button is shown. Return
  /// the chosen files (image/doc) to stage them for the next message.
  final Future<List<FilePart>> Function()? onPickAttachment;

  /// Called when the voice button is tapped; when non-null a mic button shows.
  final VoidCallback? onVoice;

  /// Models to offer; when non-empty a model selector is shown and selection is
  /// forwarded to `controller.setOptions`.
  final List<AiModelOption> models;

  @override
  State<AiPromptInput> createState() => _AiPromptInputState();
}

class _AiPromptInputState extends State<AiPromptInput> {
  final List<FilePart> _attachments = [];
  String? _modelId;

  @override
  void initState() {
    super.initState();
    if (widget.models.isNotEmpty) _modelId = widget.models.first.id;
  }

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

  void _selectModel(String id) {
    setState(() => _modelId = id);
    widget.controller.setOptions(AiRequestOptions(model: id));
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
        attachments: _attachments,
        onRemoveAttachment: (f) => setState(() => _attachments.remove(f)),
        modelSelector: widget.models.isEmpty
            ? null
            : AiModelSelector(
                models: widget.models,
                selectedId: _modelId ?? widget.models.first.id,
                onSelected: _selectModel,
              ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A modern message composer: a rounded input box with a bottom toolbar that
/// can host an attach button, a model selector, a voice button, and the
/// Send↔Stop button — plus removable previews for staged attachments.
///
/// Everything beyond the text field is opt-in: with no [onAttach], [onVoice],
/// [modelSelector], or [attachments] it's just a clean text input + send.
class AiComposer extends StatefulWidget {
  /// Creates a composer.
  const AiComposer({
    super.key,
    required this.onSend,
    this.onStop,
    this.isBusy = false,
    this.hintText = 'Message',
    this.controller,
    this.enabled = true,
    this.onAttach,
    this.onVoice,
    this.modelSelector,
    this.attachments = const [],
    this.onRemoveAttachment,
  });

  /// Called with the trimmed text when the user submits.
  final ValueChanged<String> onSend;

  /// Called when the user taps Stop while [isBusy]. If `null`, no Stop affordance
  /// is shown.
  final VoidCallback? onStop;

  /// Whether a response is in flight; controls the Send↔Stop swap.
  final bool isBusy;

  /// Placeholder text for the empty input.
  final String hintText;

  /// An optional external text controller.
  final TextEditingController? controller;

  /// Whether the input accepts text.
  final bool enabled;

  /// Shows an attach (+) button in the toolbar when non-null.
  final VoidCallback? onAttach;

  /// Shows a microphone button in the toolbar when non-null.
  final VoidCallback? onVoice;

  /// An optional widget (e.g. `AiModelSelector`) placed in the toolbar.
  final Widget? modelSelector;

  /// Staged attachments shown as removable previews above the field.
  final List<FilePart> attachments;

  /// Called to remove a staged attachment. If `null`, previews aren't removable.
  final void Function(FilePart attachment)? onRemoveAttachment;

  @override
  State<AiComposer> createState() => _AiComposerState();
}

class _AiComposerState extends State<AiComposer> {
  TextEditingController? _internalController;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty && widget.attachments.isEmpty) return;
    if (AiThemeExtension.of(context).enableHaptics) {
      unawaited(HapticFeedback.lightImpact());
    }
    widget.onSend(text);
    _controller.clear();
  }

  void _handleStop() {
    if (AiThemeExtension.of(context).enableHaptics) {
      unawaited(HapticFeedback.mediumImpact());
    }
    widget.onStop?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final showStop = widget.isBusy && widget.onStop != null;
    final subdued = theme.assistantTextColor.withValues(alpha: 0.6);

    return Padding(
      padding: theme.composerPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final file in widget.attachments)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _AttachmentPreview(
                          file: file,
                          theme: theme,
                          onRemove: widget.onRemoveAttachment == null
                              ? null
                              : () => widget.onRemoveAttachment!(file),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: theme.assistantBubbleColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.borderColor),
            ),
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _controller,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 5,
                  cursorColor: theme.accentColor,
                  style: theme.textStyle.copyWith(
                    color: theme.assistantTextColor,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: widget.enabled ? (_) => _handleSend() : null,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: theme.textStyle.copyWith(
                      color: theme.assistantTextColor.withValues(alpha: 0.45),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                Row(
                  children: [
                    if (widget.onAttach != null)
                      _ToolIcon(
                        icon: Icons.add,
                        color: subdued,
                        tooltip: 'Attach',
                        onTap: widget.enabled ? widget.onAttach : null,
                      ),
                    if (widget.modelSelector != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: widget.modelSelector,
                      ),
                    const Spacer(),
                    if (widget.onVoice != null)
                      _ToolIcon(
                        icon: Icons.mic_none_rounded,
                        color: subdued,
                        tooltip: 'Voice',
                        onTap: widget.enabled ? widget.onVoice : null,
                      ),
                    const SizedBox(width: 4),
                    _SendButton(
                      color: theme.accentColor,
                      iconColor: theme.onAccentColor,
                      icon: showStop
                          ? Icons.stop_rounded
                          : Icons.arrow_upward_rounded,
                      tooltip: showStop ? 'Stop' : 'Send',
                      onPressed: !widget.enabled
                          ? null
                          : (showStop ? _handleStop : _handleSend),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({
    required this.file,
    required this.theme,
    this.onRemove,
  });

  final FilePart file;
  final AiThemeExtension theme;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = file.mediaType.startsWith('image/');
    Widget content;
    if (isImage && (file.bytes != null || file.url != null)) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 52,
          height: 52,
          child: file.bytes != null
              ? Image.memory(file.bytes!, fit: BoxFit.cover)
              : Image.network(file.url!.toString(), fit: BoxFit.cover),
        ),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 16),
            const SizedBox(width: 6),
            Text(
              file.name ?? file.mediaType,
              style: theme.textStyle.copyWith(fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (onRemove == null) return content;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: theme.accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: theme.onAccentColor, width: 1.5),
              ),
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 12, color: theme.onAccentColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// A circular action button with a subtle press scale instead of a ripple.
class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Color color;
  final Color iconColor;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: enabled ? widget.color : widget.color.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

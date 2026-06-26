import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A presentational message composer with a Send button that swaps to a Stop
/// button while a response is streaming.
///
/// It owns no chat logic — it reports text via [onSend] and cancellation via
/// [onStop]. Bind it to a controller with `AiPromptInput`, or drive it directly.
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

  /// An optional external text controller. If omitted, one is managed
  /// internally.
  final TextEditingController? controller;

  /// Whether the input accepts text.
  final bool enabled;

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
    if (text.isEmpty) return;
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

    return Padding(
      padding: theme.composerPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: widget.enabled ? (_) => _handleSend() : null,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: OutlineInputBorder(
                  borderRadius: theme.bubbleRadius,
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.assistantBubbleColor,
                contentPadding: theme.bubblePadding,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            color: theme.userBubbleColor,
            iconColor: theme.userTextColor,
            icon: showStop ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            tooltip: showStop ? 'Stop' : 'Send',
            onPressed:
                !widget.enabled ? null : (showStop ? _handleStop : _handleSend),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: onPressed == null ? color.withValues(alpha: 0.4) : color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A presentational message composer with a Send button that swaps to a Stop
/// button while a response is streaming.
///
/// Styled as a clean rounded "pill" field with a ripple-free circular action
/// button, so it reads as a premium, platform-neutral surface rather than a
/// stock Material input. It owns no chat logic — it reports text via [onSend]
/// and cancellation via [onStop].
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
            child: Container(
              decoration: BoxDecoration(
                color: theme.assistantBubbleColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                cursorColor: theme.userBubbleColor,
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            color: theme.accentColor,
            iconColor: theme.onAccentColor,
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

/// A circular action button with a subtle press scale instead of a ripple.
class _ActionButton extends StatefulWidget {
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
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  enabled ? widget.color : widget.color.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

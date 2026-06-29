import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A modern message composer: a rounded input with a leading attach (`+`)
/// button beside the field, and a trailing pair — a secondary mic and a main
/// button that is **Live** (voice) while the field is empty and swaps to
/// **Send** once you type (hiding the mic), or **Stop** while streaming.
///
/// The model selector is intentionally *not* here — modern apps put it in the
/// app bar. Everything is opt-in via the callbacks.
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
    this.onLive,
    this.attachments = const [],
    this.onRemoveAttachment,
  });

  /// Called with the trimmed text when the user submits.
  final ValueChanged<String> onSend;

  /// Called when the user taps Stop while [isBusy].
  final VoidCallback? onStop;

  /// Whether a response is in flight; the main button shows Stop.
  final bool isBusy;

  /// Placeholder text.
  final String hintText;

  /// Optional external text controller.
  final TextEditingController? controller;

  /// Whether the input accepts text.
  final bool enabled;

  /// Shows a leading attach (`+`) button when non-null.
  final VoidCallback? onAttach;

  /// Shows a secondary mic button (voice dictation) while the field is empty.
  final VoidCallback? onVoice;

  /// When non-null, the main button is a **Live** voice button while the field
  /// is empty (it becomes Send once the user types).
  final VoidCallback? onLive;

  /// Staged attachments shown as removable previews above the field.
  final List<FilePart> attachments;

  /// Removes a staged attachment. If `null`, previews aren't removable.
  final void Function(FilePart attachment)? onRemoveAttachment;

  @override
  State<AiComposer> createState() => _AiComposerState();
}

class _AiComposerState extends State<AiComposer> {
  TextEditingController? _internalController;

  // Keeps the field (and its focus) alive when the layout reparents from the
  // single-row form to the stacked, full-width form.
  final GlobalKey _fieldKey = GlobalKey();

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void didUpdateWidget(AiComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a parent starts supplying its own controller, drop the internal one we
    // lazily created so it doesn't leak (and we stop driving a stale field).
    if (widget.controller != null && _internalController != null) {
      _internalController!.dispose();
      _internalController = null;
    }
  }

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

  // Whether [text] needs more than one line at the *single-row* field width.
  // Measured against that fixed width (not the current layout's) so the decision
  // doesn't flip-flop once the buttons drop below.
  bool _isMultiline(
    String text,
    double innerWidth,
    bool hasText,
    AiThemeExtension theme,
  ) {
    if (text.isEmpty) return false;
    if (text.contains('\n')) return true;
    const iconBox = 40.0; // _ToolIcon tap target
    const mainBtn = 38.0; // main circular button
    final attachW = widget.onAttach != null ? iconBox : 0.0;
    final micW = !hasText && widget.onVoice != null ? iconBox : 0.0;
    final trailingW = micW + 2 + mainBtn;
    final fieldLeftPad = widget.onAttach == null ? 10.0 : 2.0;
    final textWidth = innerWidth - attachW - trailingW - fieldLeftPad - 6;
    if (textWidth <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: theme.textStyle.copyWith(color: theme.assistantTextColor),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: textWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final l = AiLocalizations.of(context);
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
                        padding: const EdgeInsetsDirectional.only(end: 8),
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
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: theme.borderColor),
            ),
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                final field = TextField(
                  key: _fieldKey,
                  controller: _controller,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 6,
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                );
                final attach = widget.onAttach == null
                    ? null
                    : _ToolIcon(
                        icon: Icons.add,
                        color: subdued,
                        tooltip: l.attach,
                        onTap: widget.enabled ? widget.onAttach : null,
                      );
                final trailing = _trailing(theme, hasText, subdued, l);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    // When the text needs more than one line, give it the full
                    // width and drop the buttons to a row beneath it.
                    if (_isMultiline(
                      value.text,
                      constraints.maxWidth,
                      hasText,
                      theme,
                    )) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 8, 2),
                            child: field,
                          ),
                          Row(
                            children: [
                              if (attach != null) attach,
                              const Spacer(),
                              trailing,
                            ],
                          ),
                        ],
                      );
                    }
                    // Single-line inline layout: vertically center the icons
                    // with the field (multi-line goes to the stacked layout).
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (attach != null) attach,
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: widget.onAttach == null ? 10 : 2,
                            ),
                            child: field,
                          ),
                        ),
                        trailing,
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _trailing(
    AiThemeExtension theme,
    bool hasText,
    Color subdued,
    AiLocalizations l,
  ) {
    final showStop = widget.isBusy && widget.onStop != null;
    final liveWhenEmpty = !hasText && !showStop && widget.onLive != null;

    final IconData mainIcon;
    final VoidCallback? mainTap;
    if (showStop) {
      mainIcon = Icons.stop_rounded;
      mainTap = _handleStop;
    } else if (hasText) {
      mainIcon = Icons.arrow_upward_rounded;
      mainTap = _handleSend;
    } else if (liveWhenEmpty) {
      mainIcon = Icons.graphic_eq;
      mainTap = widget.onLive;
    } else {
      mainIcon = Icons.arrow_upward_rounded;
      mainTap = _handleSend;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Secondary mic, only while empty (and not streaming).
        if (!hasText && !showStop && widget.onVoice != null)
          _ToolIcon(
            icon: Icons.mic_none_rounded,
            color: subdued,
            tooltip: l.dictate,
            onTap: widget.enabled ? widget.onVoice : null,
          ),
        const SizedBox(width: 2),
        _MainButton(
          color: theme.accentColor,
          iconColor: theme.onAccentColor,
          icon: mainIcon,
          tooltip: showStop
              ? l.stop
              : hasText
                  ? l.send
                  : liveWhenEmpty
                      ? l.live
                      : l.send,
          onPressed: widget.enabled ? mainTap : null,
        ),
      ],
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
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 24, color: color),
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
        PositionedDirectional(
          top: -6,
          end: -6,
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

/// The circular main action button with a press scale instead of a ripple.
class _MainButton extends StatefulWidget {
  const _MainButton({
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
  State<_MainButton> createState() => _MainButtonState();
}

class _MainButtonState extends State<_MainButton> {
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  enabled ? widget.color : widget.color.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

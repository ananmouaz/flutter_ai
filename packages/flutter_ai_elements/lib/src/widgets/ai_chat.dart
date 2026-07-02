import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';
import 'package:flutter_ai_elements/src/rendering/ai_text_renderer.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';
import 'package:flutter_ai_elements/src/widgets/ai_conversation_view.dart';
import 'package:flutter_ai_elements/src/widgets/ai_haptics.dart';
import 'package:flutter_ai_elements/src/widgets/ai_response.dart';

/// A live, drop-in chat transcript bound to a [UseChatController].
///
/// Rebuilds as the controller's transcript changes and shows a thinking loader
/// while awaiting the first token.
///
/// When you send a message, the chat anchors that message to the **top** of the
/// viewport (ChatGPT-style) and lets the answer stream into the space below it,
/// reserving just enough trailing space and releasing it as the answer grows.
///
/// Named `AiChat` rather than `AiConversation` to avoid colliding with the
/// `AiConversation` data model from `flutter_ai_core`.
class AiChat extends StatefulWidget {
  /// Creates a chat transcript bound to [controller].
  const AiChat({
    super.key,
    required this.controller,
    this.textRenderer = const MarkdownTextRenderer(),
    this.messageBuilder,
    this.padding = const EdgeInsets.all(16),
    this.autoScroll = true,
    this.emptyState,
    this.loadingBuilder,
    this.maxContentWidth,
  });

  /// The chat controller to observe.
  final UseChatController controller;

  /// Shown in place of the list while the conversation is empty and idle.
  final Widget? emptyState;

  /// Renderer for message text.
  final AiTextRenderer textRenderer;

  /// Optional override for how each message is built.
  final Widget Function(BuildContext context, AiMessage message)?
      messageBuilder;

  /// Padding around the list.
  final EdgeInsets padding;

  /// Whether to auto-scroll to the newest message when already near the bottom.
  final bool autoScroll;

  /// Builds the thinking indicator (defaults to `AiLoader`).
  final WidgetBuilder? loadingBuilder;

  /// On wide screens, centers the conversation at this width. When `null`,
  /// falls back to [AiThemeExtension.maxContentWidth]; pass [double.infinity]
  /// for full-width.
  final double? maxContentWidth;

  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _anchorKey = GlobalKey();

  /// Id of the user message currently pinned to the top of the viewport.
  String? _anchorId;

  /// Empty space reserved after the last item so the anchor can reach the top.
  double _trailingSpace = 0;

  /// Whether we're actively holding the anchor at the top. Released when the
  /// user scrolls manually, re-armed on the next sent message.
  bool _pinned = false;

  /// Whether to show the floating "scroll to latest" button.
  bool _showJump = false;
  int _lastCount = 0;

  /// The controller status at the previous change, to detect turn completion.
  ChatStatus? _lastStatus;

  /// Bounds the per-change settle retries (waiting for the anchor to lay out).
  int _settleAttempts = 0;

  /// Coalesces overlapping settle callbacks into one per frame.
  bool _settleScheduled = false;

  @override
  void initState() {
    super.initState();
    _lastCount = widget.controller.messages.length;
    _lastStatus = widget.controller.status;
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(AiChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _scrollController.dispose();
    super.dispose();
  }

  void _onChange() {
    // A light tap when a turn finishes (busy → idle) — independent of scrolling.
    final status = widget.controller.status;
    if (_lastStatus != null &&
        _lastStatus!.isBusy &&
        !status.isBusy &&
        mounted) {
      aiLightHaptic(AiThemeExtension.of(context));
    }
    _lastStatus = status;

    if (!widget.autoScroll) return;
    final messages = widget.controller.messages;
    final count = messages.length;
    final newMessage = count > _lastCount;
    _lastCount = count;

    if (messages.isEmpty) {
      if (_anchorId != null || _trailingSpace != 0) {
        setState(() {
          _anchorId = null;
          _trailingSpace = 0;
          _pinned = false;
          _showJump = false;
        });
      }
      return;
    }

    if (newMessage) {
      // Pin the latest user turn to the top for the whole turn. Start with no
      // reserved space so the freshly-appended anchor (the last item) is within
      // the lazy list's build area; _settle() then reserves what's needed and
      // holds the anchor at the top as the answer streams in.
      final lastUser = _lastUserId(messages);
      if (lastUser != null) {
        setState(() {
          _anchorId = lastUser;
          _trailingSpace = 0;
          _pinned = true;
        });
      }
    }
    // Re-assert the anchor every change while pinned so it *persists* at the top
    // as the answer streams (not just on the first frame).
    _settle();
  }

  static String? _lastUserId(List<AiMessage> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == AiRole.user) return messages[i].id;
    }
    return null;
  }

  /// Re-asserts the top-pin: reserves just enough trailing space for the
  /// anchored message to reach the top, then holds it there. Retries across a
  /// few frames while the anchor (or viewport) finishes laying out.
  void _settle() {
    _settleAttempts = 0;
    _scheduleSettle();
  }

  void _scheduleSettle() {
    if (_settleScheduled) return;
    _settleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleScheduled = false;
      _doSettle();
    });
  }

  void _doSettle() {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (!pos.haveDimensions) {
      if (_settleAttempts++ < 12) _scheduleSettle();
      return;
    }
    if (!_pinned || _anchorId == null) {
      _updateJump();
      return;
    }

    final box = _anchorKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) {
      // The just-appended anchor isn't built yet. Nudge toward the end (it's the
      // last real item, so this builds it) and retry — NEVER leave it bottom-
      // pinned, which is what produced "shows previous messages".
      if (_settleAttempts++ < 12) {
        _scrollController.jumpTo(pos.maxScrollExtent);
        _scheduleSettle();
      }
      return;
    }

    final viewport = pos.viewportDimension;
    // Offset that puts the anchor at the very top — independent of the trailing
    // spacer (which is below the anchor), so it's stable across frames.
    final reveal =
        RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
    // Body height excluding the current spacer, computed from this frame's
    // consistent (max, trailing) pair — avoids the off-by-one feedback that made
    // the reservation oscillate and the anchor land short of the top.
    final body = pos.maxScrollExtent + viewport - _trailingSpace;
    final contentBelow = body - reveal;
    final desired = (viewport - contentBelow).clamp(0.0, viewport);

    if ((desired - _trailingSpace).abs() > 0.5) {
      // Set the reservation and pin on the next frame, once it has laid out —
      // don't jump using the stale (pre-relayout) extents.
      setState(() => _trailingSpace = desired);
      if (_settleAttempts++ < 12) _scheduleSettle();
      return;
    }
    // Reservation is correct for this layout: pin the anchor to the top.
    _scrollController.jumpTo(reveal.clamp(0.0, pos.maxScrollExtent));
    _updateJump();
  }

  /// Shows the jump button whenever there's content below the fold.
  void _updateJump() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final show = pos.maxScrollExtent - pos.pixels > 240;
    if (show != _showJump) setState(() => _showJump = show);
  }

  // A user-initiated scroll away from the bottom releases the top-pin so we stop
  // fighting the user, and frees the reserved space so they can't scroll into
  // empty space below the last message.
  //
  // Touch drags surface as a ScrollStartNotification with dragDetails; mouse
  // wheel, trackpad, and keyboard scrolling surface only as a
  // UserScrollNotification (programmatic jumpTo never emits one, so this won't
  // self-trigger). Releasing on an upward user scroll covers all input types.
  bool _onScrollNotification(ScrollNotification n) {
    final userDrag = n is ScrollStartNotification && n.dragDetails != null;
    final scrolledUp =
        n is UserScrollNotification && n.direction == ScrollDirection.forward;
    if (_pinned && (userDrag || scrolledUp)) {
      _pinned = false;
      if (_trailingSpace != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_pinned && _trailingSpace != 0) {
            setState(() => _trailingSpace = 0);
          }
        });
      }
    }
    _updateJump();
    return false;
  }

  void _jumpToLatest() {
    _pinned = false;
    if (_scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        if (widget.emptyState != null &&
            widget.controller.messages.isEmpty &&
            !widget.controller.status.isBusy) {
          return widget.emptyState!;
        }
        final view = AiConversationView(
          messages: widget.controller.messages,
          scrollController: _scrollController,
          textRenderer: widget.textRenderer,
          messageBuilder: widget.messageBuilder,
          loadingBuilder: widget.loadingBuilder,
          maxContentWidth: widget.maxContentWidth,
          padding: widget.padding,
          // Show the loader only while awaiting the first streamed token.
          showLoader: widget.controller.status == ChatStatus.submitted,
          trailingSpace: widget.autoScroll ? _trailingSpace : 0,
          anchorKey: _anchorKey,
          anchorId: _anchorId,
        );
        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: Stack(
            children: [
              view,
              if (_showJump)
                PositionedDirectional(
                  bottom: 8,
                  start: 0,
                  end: 0,
                  child: Center(child: _JumpButton(onTap: _jumpToLatest)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A small circular "scroll to latest" affordance, shown when the conversation
/// has scrolled above the bottom.
class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    return Semantics(
      button: true,
      label: AiLocalizations.of(context).scrollToLatest,
      child: Material(
        color: theme.assistantBubbleColor,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_downward_rounded,
              size: 20,
              color: theme.assistantTextColor,
            ),
          ),
        ),
      ),
    );
  }
}

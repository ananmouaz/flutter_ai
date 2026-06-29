import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_elements/src/rendering/ai_text_renderer.dart';
import 'package:flutter_ai_elements/src/widgets/ai_conversation_view.dart';
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

  /// On wide screens, centers the conversation at this width. `null` is
  /// full-width.
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
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _lastCount = widget.controller.messages.length;
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
        });
      }
      return;
    }

    if (newMessage) {
      // Anchor the latest user turn to the top and reserve a screenful of space
      // so it can get there even before the answer fills it; _settle() shrinks
      // the reservation back as the answer streams in.
      final lastUser = _lastUserId(messages);
      if (lastUser != null) {
        final viewport = _scrollController.hasClients
            ? _scrollController.position.viewportDimension
            : MediaQuery.maybeSizeOf(context)?.height ?? 600;
        setState(() {
          _anchorId = lastUser;
          _trailingSpace = viewport;
        });
        _settle(scrollToAnchor: true);
        return;
      }
    }
    // Streaming tokens (or no user message): keep the anchor in place and just
    // release reserved space as content grows.
    _settle(scrollToAnchor: false);
  }

  static String? _lastUserId(List<AiMessage> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == AiRole.user) return messages[i].id;
    }
    return null;
  }

  /// Trims the trailing reservation so the anchored message sits at the top with
  /// no excess blank space, optionally jumping it there.
  void _settle({required bool scrollToAnchor}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final box = _anchorKey.currentContext?.findRenderObject();
      if (_anchorId == null || box is! RenderBox || !box.attached) {
        // Fallback: classic bottom pin.
        if (scrollToAnchor || pos.maxScrollExtent - pos.pixels < 120) {
          _scrollController.jumpTo(pos.maxScrollExtent);
        }
        return;
      }
      final viewport = pos.viewportDimension;
      final reveal =
          RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
      // Reserve only as much as is needed for the anchor to reach the top
      // (maxScrollExtent must stay >= reveal); release the rest as content grows.
      final desired =
          (_trailingSpace + reveal - pos.maxScrollExtent).clamp(0.0, viewport);
      if ((desired - _trailingSpace).abs() > 0.5) {
        setState(() => _trailingSpace = desired);
      }
      if (scrollToAnchor) {
        // Jump after the reservation settles on the next frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final p = _scrollController.position;
          final b = _anchorKey.currentContext?.findRenderObject();
          if (b is! RenderBox || !b.attached) return;
          final r = RenderAbstractViewport.of(b).getOffsetToReveal(b, 0).offset;
          _scrollController.jumpTo(r.clamp(0.0, p.maxScrollExtent));
        });
      }
    });
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
        return AiConversationView(
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
      },
    );
  }
}

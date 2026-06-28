import 'package:flutter/widgets.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_elements/src/rendering/ai_text_renderer.dart';
import 'package:flutter_ai_elements/src/widgets/ai_conversation_view.dart';
import 'package:flutter_ai_elements/src/widgets/ai_response.dart';

/// A live, drop-in chat transcript bound to a [UseChatController].
///
/// Rebuilds as the controller's transcript changes, shows a thinking loader
/// while awaiting the first token, and keeps the view pinned to the latest
/// message when the user is already at the bottom.
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
    final count = widget.controller.messages.length;
    // A new message (the user's, or a fresh assistant turn) always jumps to the
    // end; streaming tokens only stick if the user hasn't scrolled away.
    final newMessage = count > _lastCount;
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      final nearBottom = position.maxScrollExtent - position.pixels < 120;
      if (!newMessage && !nearBottom) return;
      _scrollController.jumpTo(position.maxScrollExtent);
      // A second pass catches the extent growing as lazy items lay out (a tall
      // new bubble can exceed the first estimate).
      if (newMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
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
        );
      },
    );
  }
}

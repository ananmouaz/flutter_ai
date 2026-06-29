import 'package:flutter/widgets.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/rendering/ai_text_renderer.dart';
import 'package:flutter_ai_elements/src/widgets/ai_loader.dart';
import 'package:flutter_ai_elements/src/widgets/ai_message_bubble.dart';
import 'package:flutter_ai_elements/src/widgets/ai_response.dart';

/// A scrolling list of message bubbles.
///
/// Presentational: it renders the [messages] it is given and reports nothing
/// back. The controller-bound `AiConversation` wraps it with live updates and
/// auto-scroll.
class AiConversationView extends StatefulWidget {
  /// Creates a conversation view.
  const AiConversationView({
    super.key,
    required this.messages,
    this.scrollController,
    this.textRenderer = const MarkdownTextRenderer(),
    this.messageBuilder,
    this.showLoader = false,
    this.loadingBuilder,
    this.padding = const EdgeInsets.all(16),
    this.maxContentWidth,
    this.trailingSpace = 0,
    this.anchorKey,
    this.anchorId,
  });

  /// The messages to display, oldest first.
  final List<AiMessage> messages;

  /// Optional scroll controller, supplied by a parent that manages scrolling.
  final ScrollController? scrollController;

  /// Renderer for message text. Defaults to [MarkdownTextRenderer].
  final AiTextRenderer textRenderer;

  /// Optional override for how each message is built.
  final Widget Function(BuildContext context, AiMessage message)?
      messageBuilder;

  /// Whether to append a thinking indicator after the last message.
  final bool showLoader;

  /// Builds the thinking indicator shown when [showLoader] is true. Defaults to
  /// an `AiLoader`; pass one returning `AiShimmer` for a skeleton instead.
  final WidgetBuilder? loadingBuilder;

  /// Padding around the list.
  final EdgeInsets padding;

  /// On wide screens, centers the conversation at this width (like ChatGPT on
  /// tablet/desktop). `null` means full-width.
  final double? maxContentWidth;

  /// Extra empty space reserved after the last item. Used by `AiChat` to let the
  /// newest turn scroll to the top of the viewport (ChatGPT-style anchoring).
  final double trailingSpace;

  /// When set, the message whose [AiMessage.id] equals [anchorId] is wrapped in
  /// a [KeyedSubtree] keyed by this, so a parent can scroll it into view.
  final GlobalKey? anchorKey;

  /// The id of the message to attach [anchorKey] to.
  final Object? anchorId;

  @override
  State<AiConversationView> createState() => _AiConversationViewState();
}

class _AiConversationViewState extends State<AiConversationView> {
  // Memoize the built bubble per message identity. While streaming, only the
  // changed message gets a new AiMessage instance, so unchanged bubbles return
  // the *same* widget instance and Flutter skips their rebuild entirely.
  final Map<String, AiMessage> _cachedMessage = {};
  final Map<String, Widget> _cachedBubble = {};

  void _clearCache() {
    _cachedMessage.clear();
    _cachedBubble.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clearCache(); // theme/inherited changed — bubbles may need restyling
  }

  @override
  void didUpdateWidget(AiConversationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textRenderer != widget.textRenderer ||
        oldWidget.messageBuilder != widget.messageBuilder) {
      _clearCache();
    }
  }

  Widget _bubbleFor(BuildContext context, AiMessage message) {
    // Custom builders aren't memoized (they may capture changing state).
    if (widget.messageBuilder != null) {
      return widget.messageBuilder!(context, message);
    }
    if (identical(_cachedMessage[message.id], message)) {
      return _cachedBubble[message.id]!;
    }
    final bubble = AiMessageBubble(
      key: ValueKey(message.id),
      message: message,
      textRenderer: widget.textRenderer,
    );
    _cachedMessage[message.id] = message;
    _cachedBubble[message.id] = bubble;
    return bubble;
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    final showLoader = widget.showLoader;
    final hasSpacer = widget.trailingSpace > 0;
    final loaderIndex = showLoader ? messages.length : -1;
    final spacerIndex = hasSpacer ? messages.length + (showLoader ? 1 : 0) : -1;
    final itemCount =
        messages.length + (showLoader ? 1 : 0) + (hasSpacer ? 1 : 0);
    final list = ListView.builder(
      controller: widget.scrollController,
      padding: widget.padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == spacerIndex) {
          return SizedBox(height: widget.trailingSpace);
        }
        if (index == loaderIndex) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: widget.loadingBuilder?.call(context) ?? const AiLoader(),
            ),
          );
        }
        final message = messages[index];
        final bubble = _bubbleFor(context, message);
        if (widget.anchorKey != null && widget.anchorId == message.id) {
          return KeyedSubtree(key: widget.anchorKey, child: bubble);
        }
        return bubble;
      },
    );
    if (widget.maxContentWidth == null) return list;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxContentWidth!),
        child: list,
      ),
    );
  }
}

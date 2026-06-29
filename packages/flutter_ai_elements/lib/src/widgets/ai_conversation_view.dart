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
class AiConversationView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final hasSpacer = trailingSpace > 0;
    final loaderIndex = showLoader ? messages.length : -1;
    final spacerIndex = hasSpacer ? messages.length + (showLoader ? 1 : 0) : -1;
    final itemCount =
        messages.length + (showLoader ? 1 : 0) + (hasSpacer ? 1 : 0);
    final list = ListView.builder(
      controller: scrollController,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == spacerIndex) return SizedBox(height: trailingSpace);
        if (index == loaderIndex) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: loadingBuilder?.call(context) ?? const AiLoader(),
            ),
          );
        }
        final message = messages[index];
        final bubble = messageBuilder?.call(context, message) ??
            AiMessageBubble(
              key: ValueKey(message.id),
              message: message,
              textRenderer: textRenderer,
            );
        if (anchorKey != null && anchorId == message.id) {
          return KeyedSubtree(key: anchorKey, child: bubble);
        }
        return bubble;
      },
    );
    if (maxContentWidth == null) return list;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth!),
        child: list,
      ),
    );
  }
}

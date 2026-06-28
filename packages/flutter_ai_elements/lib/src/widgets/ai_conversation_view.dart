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

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (showLoader ? 1 : 0);
    final list = ListView.builder(
      controller: scrollController,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showLoader && index == messages.length) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: loadingBuilder?.call(context) ?? const AiLoader(),
            ),
          );
        }
        final message = messages[index];
        return messageBuilder?.call(context, message) ??
            AiMessageBubble(
              key: ValueKey(message.id),
              message: message,
              textRenderer: textRenderer,
            );
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

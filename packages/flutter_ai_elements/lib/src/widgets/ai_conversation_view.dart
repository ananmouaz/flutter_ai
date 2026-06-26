import 'package:flutter/widgets.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/rendering/ai_text_renderer.dart';
import 'package:flutter_ai_elements/src/widgets/ai_loader.dart';
import 'package:flutter_ai_elements/src/widgets/ai_message_bubble.dart';

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
    this.textRenderer = const PlainTextRenderer(),
    this.messageBuilder,
    this.showLoader = false,
    this.padding = const EdgeInsets.all(16),
  });

  /// The messages to display, oldest first.
  final List<AiMessage> messages;

  /// Optional scroll controller, supplied by a parent that manages scrolling.
  final ScrollController? scrollController;

  /// Renderer for message text. Defaults to [PlainTextRenderer].
  final AiTextRenderer textRenderer;

  /// Optional override for how each message is built.
  final Widget Function(BuildContext context, AiMessage message)?
      messageBuilder;

  /// Whether to append a thinking [AiLoader] after the last message.
  final bool showLoader;

  /// Padding around the list.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (showLoader ? 1 : 0);
    return ListView.builder(
      controller: scrollController,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showLoader && index == messages.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: AiLoader(),
            ),
          );
        }
        final message = messages[index];
        return messageBuilder?.call(context, message) ??
            AiMessageBubble(message: message, textRenderer: textRenderer);
      },
    );
  }
}

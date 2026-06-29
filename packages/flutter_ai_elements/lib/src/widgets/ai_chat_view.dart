import 'package:flutter/widgets.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';
import 'package:flutter_ai_elements/src/rendering/ai_text_renderer.dart';
import 'package:flutter_ai_elements/src/widgets/ai_chat.dart';
import 'package:flutter_ai_elements/src/widgets/ai_prompt_input.dart';
import 'package:flutter_ai_elements/src/widgets/ai_response.dart'
    show MarkdownTextRenderer;

/// A batteries-included chat surface: the [AiChat] transcript above an
/// [AiPromptInput], laid out and safe-area-aware. Drop it straight into a
/// `Scaffold` body — the fastest path from `pub add` to a working chat:
///
/// ```dart
/// Scaffold(body: AiChatView(controller: controller));
/// ```
///
/// Everything is overridable; reach for [AiChat] + [AiPromptInput] directly
/// only when you need a custom layout between them.
class AiChatView extends StatelessWidget {
  /// Creates a chat surface bound to [controller].
  const AiChatView({
    super.key,
    required this.controller,
    this.textRenderer = const MarkdownTextRenderer(),
    this.emptyState,
    this.hintText,
    this.maxContentWidth,
    this.onPickAttachment,
    this.onVoice,
    this.onLive,
    this.messageBuilder,
  });

  /// The chat controller to drive the transcript and input.
  final UseChatController controller;

  /// Renderer for message text. Defaults to [MarkdownTextRenderer].
  final AiTextRenderer textRenderer;

  /// Shown when the conversation is empty.
  final Widget? emptyState;

  /// Composer placeholder. Defaults to the localized "Message".
  final String? hintText;

  /// On wide screens, centers the transcript at this width (like ChatGPT).
  final double? maxContentWidth;

  /// Stages attachments to send with the next message. Hidden when null.
  final Future<List<FilePart>> Function()? onPickAttachment;

  /// Voice-dictation entry point. Hidden when null.
  final VoidCallback? onVoice;

  /// Live-voice entry point. Hidden when null.
  final VoidCallback? onLive;

  /// Optional override for how each message is built.
  final Widget Function(BuildContext context, AiMessage message)?
      messageBuilder;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: AiChat(
              controller: controller,
              textRenderer: textRenderer,
              emptyState: emptyState,
              maxContentWidth: maxContentWidth,
              messageBuilder: messageBuilder,
            ),
          ),
          AiPromptInput(
            controller: controller,
            hintText: hintText ?? AiLocalizations.of(context).messageHint,
            onPickAttachment: onPickAttachment,
            onVoice: onVoice,
            onLive: onLive,
          ),
        ],
      ),
    );
  }
}

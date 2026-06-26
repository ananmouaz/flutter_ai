import 'package:flutter/material.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/rendering/ai_text_renderer.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';
import 'package:flutter_ai_elements/src/widgets/ai_attachment.dart';
import 'package:flutter_ai_elements/src/widgets/ai_reasoning.dart';
import 'package:flutter_ai_elements/src/widgets/ai_tool_invocation.dart';

/// A single chat bubble that renders one [AiMessage]'s parts.
///
/// Purely presentational — it takes data, not a controller — so it is trivially
/// testable and reusable. Styling comes entirely from [AiThemeExtension].
///
/// Each part type gets an appropriate widget: prose via the [textRenderer],
/// reasoning via `AiReasoning`, tool calls via `AiToolInvocation` (paired with
/// their results), files via `AiAttachment`, and sources as link chips.
///
/// ### Accessibility while streaming
///
/// Rapidly updating text floods screen readers. While [AiMessage.status] is
/// [AiMessageStatus.streaming] the bubble is wrapped in [ExcludeSemantics];
/// once the message completes it becomes a live region so assistive technology
/// announces the finished answer exactly once.
class AiMessageBubble extends StatelessWidget {
  /// Creates a message bubble.
  const AiMessageBubble({
    super.key,
    required this.message,
    this.textRenderer = const PlainTextRenderer(),
  });

  /// The message to render.
  final AiMessage message;

  /// How text and reasoning parts are rendered. Defaults to [PlainTextRenderer].
  final AiTextRenderer textRenderer;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final isUser = message.role == AiRole.user;
    final isStreaming = message.status == AiMessageStatus.streaming;

    final bubble = Container(
      decoration: BoxDecoration(
        color: isUser ? theme.userBubbleColor : theme.assistantBubbleColor,
        borderRadius: theme.bubbleRadius,
        boxShadow: theme.bubbleShadow,
      ),
      padding: theme.bubblePadding,
      child: DefaultTextStyle.merge(
        style: theme.textStyle.copyWith(
          color: isUser ? theme.userTextColor : theme.assistantTextColor,
        ),
        child: _content(context, isStreaming),
      ),
    );

    final aligned = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:
              MediaQuery.sizeOf(context).width * theme.maxBubbleWidthFraction,
        ),
        child: bubble,
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: theme.messageSpacing),
      child: isStreaming
          ? ExcludeSemantics(child: aligned)
          : Semantics(liveRegion: true, child: aligned),
    );
  }

  Widget _content(BuildContext context, bool isStreaming) {
    // Pair tool results with their calls so each renders inside one card.
    final results = <String, ToolResultPart>{
      for (final part in message.parts)
        if (part is ToolResultPart) part.toolCallId: part,
    };

    final children = <Widget>[];
    for (final part in message.parts) {
      switch (part) {
        case TextPart(:final text):
          children.add(textRenderer.render(text, isStreaming: isStreaming));
        case ReasoningPart(:final text):
          children.add(AiReasoning(text: text));
        case ToolCallPart():
          children.add(
            AiToolInvocation(call: part, result: results[part.toolCallId]),
          );
        case ToolResultPart():
          // Rendered within its AiToolInvocation; skip the standalone part.
          break;
        case FilePart():
          children.add(AiAttachment(file: part));
        case SourcePart(:final url, :final title):
          children.add(_SourceChip(url: url, title: title));
        case DataPart(:final dataType):
          children.add(_DataChip(label: dataType));
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          children[i],
        ],
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.url, this.title});

  final Uri url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.link, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            title ?? url.toString(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

class _DataChip extends StatelessWidget {
  const _DataChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.widgets_outlined, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}

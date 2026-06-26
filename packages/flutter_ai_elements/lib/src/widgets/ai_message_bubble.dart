import 'package:flutter/material.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/rendering/ai_text_renderer.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A single chat bubble that renders one [AiMessage]'s parts.
///
/// Purely presentational — it takes data, not a controller — so it is trivially
/// testable and reusable. Styling comes entirely from [AiThemeExtension].
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
        child: _content(context, theme, isStreaming),
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

  Widget _content(
    BuildContext context,
    AiThemeExtension theme,
    bool isStreaming,
  ) {
    final children = <Widget>[];
    for (final part in message.parts) {
      switch (part) {
        case TextPart(:final text):
          children.add(textRenderer.render(text, isStreaming: isStreaming));
        case ReasoningPart(:final text):
          children.add(_ReasoningBlock(text: text));
        case ToolCallPart(:final toolName, :final state):
          children.add(
            _ToolLine(
              icon: Icons.build_outlined,
              label: state == ToolCallState.outputAvailable
                  ? '$toolName · done'
                  : '$toolName · ${state.name}',
              theme: theme,
            ),
          );
        case ToolResultPart(:final isError):
          children.add(
            _ToolLine(
              icon: isError ? Icons.error_outline : Icons.check_circle_outline,
              label: isError ? 'Tool error' : 'Tool result',
              theme: theme,
            ),
          );
        case FilePart(:final name, :final mediaType):
          children.add(
            _ToolLine(
              icon: Icons.attach_file,
              label: name ?? mediaType,
              theme: theme,
            ),
          );
        case SourcePart(:final url, :final title):
          children.add(
            _ToolLine(
              icon: Icons.link,
              label: title ?? url.toString(),
              theme: theme,
            ),
          );
        case DataPart(:final dataType):
          children.add(
            _ToolLine(
              icon: Icons.widgets_outlined,
              label: dataType,
              theme: theme,
            ),
          );
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          children[i],
        ],
      ],
    );
  }
}

class _ReasoningBlock extends StatelessWidget {
  const _ReasoningBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color?.withValues(
          alpha: 0.6,
        );
    return Text(
      text,
      style: TextStyle(fontStyle: FontStyle.italic, color: color),
    );
  }
}

class _ToolLine extends StatelessWidget {
  const _ToolLine({
    required this.icon,
    required this.label,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final AiThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: theme.codeStyle.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

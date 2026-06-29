import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A collapsible disclosure for the model's reasoning ("chain of thought").
///
/// Kept out of the main answer flow and collapsed by default so reasoning is
/// available without dominating the bubble.
class AiReasoning extends StatefulWidget {
  /// Creates a reasoning disclosure for [text].
  const AiReasoning({
    super.key,
    required this.text,
    this.initiallyExpanded = false,
  });

  /// The reasoning content.
  final String text;

  /// Whether the disclosure starts expanded.
  final bool initiallyExpanded;

  @override
  State<AiReasoning> createState() => _AiReasoningState();
}

class _AiReasoningState extends State<AiReasoning> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    final subdued = color?.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_outlined, size: 16, color: subdued),
                const SizedBox(width: 6),
                Text(
                  AiLocalizations.of(context).reasoning,
                  style: TextStyle(
                    color: subdued,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: subdued,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: theme.motionDuration,
          curve: theme.motionCurve,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    widget.text,
                    style: theme.textStyle.copyWith(
                      color: subdued,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

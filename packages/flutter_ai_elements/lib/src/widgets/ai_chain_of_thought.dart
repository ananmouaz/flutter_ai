import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// One step in an [AiChainOfThought].
@immutable
class AiThoughtStep {
  /// Creates a step with a [label] and optional [detail].
  const AiThoughtStep({
    required this.label,
    this.detail,
    this.isActive = false,
  });

  /// The step's headline.
  final String label;

  /// Optional supporting detail shown beneath the label.
  final String? detail;

  /// Whether this step is the one currently in progress.
  final bool isActive;
}

/// A collapsible, vertical timeline of reasoning steps.
///
/// Richer than `AiReasoning` (which shows free-form text): use this when the
/// model exposes discrete steps (search → read → synthesize).
class AiChainOfThought extends StatefulWidget {
  /// Creates a chain-of-thought timeline from [steps].
  const AiChainOfThought({
    super.key,
    required this.steps,
    this.title = 'Chain of thought',
    this.initiallyExpanded = false,
  });

  /// The ordered steps.
  final List<AiThoughtStep> steps;

  /// The disclosure label.
  final String title;

  /// Whether the timeline starts expanded.
  final bool initiallyExpanded;

  @override
  State<AiChainOfThought> createState() => _AiChainOfThoughtState();
}

class _AiChainOfThoughtState extends State<AiChainOfThought> {
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
                Icon(Icons.account_tree_outlined, size: 16, color: subdued),
                const SizedBox(width: 6),
                Text(
                  widget.title,
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
                  padding: const EdgeInsets.only(top: 8, left: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.steps.length; i++)
                        _StepRow(
                          step: widget.steps[i],
                          isLast: i == widget.steps.length - 1,
                          theme: theme,
                          textColor: color,
                          subdued: subdued,
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isLast,
    required this.theme,
    required this.textColor,
    required this.subdued,
  });

  final AiThoughtStep step;
  final bool isLast;
  final AiThemeExtension theme;
  final Color? textColor;
  final Color? subdued;

  @override
  Widget build(BuildContext context) {
    final dotColor = step.isActive ? theme.accentColor : subdued;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 4),
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1.5, color: theme.borderColor),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: theme.textStyle.copyWith(
                      color: textColor,
                      fontSize: 14.5,
                      fontWeight:
                          step.isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (step.detail != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        step.detail!,
                        style: theme.textStyle.copyWith(
                          color: subdued,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

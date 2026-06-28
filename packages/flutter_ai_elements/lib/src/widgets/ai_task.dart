import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// The state of an [AiTaskItem].
enum AiTaskStatus {
  /// Not started yet.
  pending,

  /// Currently running.
  active,

  /// Finished successfully.
  complete,

  /// Failed.
  error,
}

/// One line item within an [AiTask].
@immutable
class AiTaskItem {
  /// Creates a task item.
  const AiTaskItem({required this.label, this.status = AiTaskStatus.pending});

  /// The item text (a step, a file name, …).
  final String label;

  /// The item's status, which selects its leading icon.
  final AiTaskStatus status;
}

/// A collapsible "task" card showing a titled checklist the agent works
/// through — each item with a pending/active/complete/error indicator.
class AiTask extends StatefulWidget {
  /// Creates a task card.
  const AiTask({
    super.key,
    required this.title,
    required this.items,
    this.initiallyExpanded = true,
  });

  /// The task headline.
  final String title;

  /// The checklist items.
  final List<AiTaskItem> items;

  /// Whether the card starts expanded.
  final bool initiallyExpanded;

  @override
  State<AiTask> createState() => _AiTaskState();
}

class _AiTaskState extends State<AiTask> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    final done = widget.items.where((i) => i.status == AiTaskStatus.complete);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.checklist_rtl, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textStyle.copyWith(
                          color: color,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${done.length}/${widget.items.length}',
                      style: theme.codeStyle.copyWith(
                        color: color?.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: color?.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: theme.motionDuration,
            curve: theme.motionCurve,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in widget.items)
                          _ItemRow(item: item, theme: theme, textColor: color),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.theme,
    required this.textColor,
  });

  final AiTaskItem item;
  final AiThemeExtension theme;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.status) {
      AiTaskStatus.complete => (
          Icons.check_circle,
          const Color(0xFF16A34A),
        ),
      AiTaskStatus.active => (Icons.adjust, theme.accentColor),
      AiTaskStatus.error => (Icons.error, const Color(0xFFDC2626)),
      AiTaskStatus.pending => (
          Icons.radio_button_unchecked,
          textColor?.withValues(alpha: 0.4) ?? const Color(0xFF999999),
        ),
    };
    final faded = item.status == AiTaskStatus.pending;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              style: theme.textStyle.copyWith(
                color: faded ? textColor?.withValues(alpha: 0.6) : textColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

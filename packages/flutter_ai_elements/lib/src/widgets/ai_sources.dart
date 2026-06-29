import 'package:flutter/material.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A wrapped list of citation chips built from [SourcePart]s.
///
/// Render it beneath an answer to show where the model's information came from.
/// Tapping a chip invokes [onTap] (wire it to a URL launcher).
///
/// Grounded answers can return dozens of sources, so by default only the first
/// [maxVisible] chips are shown with a "+N more" toggle; tapping it reveals the
/// rest. Set [maxVisible] to `null` to always show every source.
class AiSources extends StatefulWidget {
  /// Creates a sources strip.
  const AiSources({
    super.key,
    required this.sources,
    this.onTap,
    this.maxVisible = 6,
  });

  /// The citations to display.
  final List<SourcePart> sources;

  /// Called with the tapped source.
  final void Function(SourcePart source)? onTap;

  /// How many chips to show before collapsing the rest behind a "+N more"
  /// toggle. `null` shows all sources.
  final int? maxVisible;

  @override
  State<AiSources> createState() => _AiSourcesState();
}

class _AiSourcesState extends State<AiSources> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sources = widget.sources;
    if (sources.isEmpty) return const SizedBox.shrink();
    final theme = AiThemeExtension.of(context);

    final cap = widget.maxVisible;
    final collapsible = cap != null && sources.length > cap;
    final visible =
        (collapsible && !_expanded) ? sources.take(cap).toList() : sources;
    final hiddenCount = collapsible ? sources.length - cap : 0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final source in visible)
          _SourceChip(
            label: source.title ?? source.url.host,
            theme: theme,
            onTap: widget.onTap == null ? null : () => widget.onTap!(source),
          ),
        if (collapsible)
          _SourceChip(
            label: _expanded ? 'Show less' : '+$hiddenCount more',
            icon: _expanded
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            theme: theme,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.theme,
    required this.onTap,
    this.icon = Icons.link,
  });

  final String label;
  final AiThemeExtension theme;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.assistantBubbleColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: theme.assistantTextColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: theme.assistantTextColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

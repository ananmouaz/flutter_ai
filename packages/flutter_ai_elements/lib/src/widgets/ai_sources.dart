import 'package:flutter/material.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A wrapped list of citation chips built from [SourcePart]s.
///
/// Render it beneath an answer to show where the model's information came from.
/// Tapping a chip invokes [onTap] (wire it to a URL launcher).
class AiSources extends StatelessWidget {
  /// Creates a sources strip.
  const AiSources({super.key, required this.sources, this.onTap});

  /// The citations to display.
  final List<SourcePart> sources;

  /// Called with the tapped source.
  final void Function(SourcePart source)? onTap;

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();
    final theme = AiThemeExtension.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final source in sources)
          _SourceChip(
            label: source.title ?? source.url.host,
            theme: theme,
            onTap: onTap == null ? null : () => onTap!(source),
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
  });

  final String label;
  final AiThemeExtension theme;
  final VoidCallback? onTap;

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
              Icon(Icons.link, size: 14, color: theme.assistantTextColor),
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

import 'package:flutter/material.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';
import 'package:flutter_ai_elements/src/widgets/ai_haptics.dart';

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
    this.showFavicons = false,
  });

  /// The citations to display.
  final List<SourcePart> sources;

  /// Called with the tapped source.
  final void Function(SourcePart source)? onTap;

  /// How many chips to show before collapsing the rest behind a "+N more"
  /// toggle. `null` shows all sources.
  final int? maxVisible;

  /// Whether to fetch and show a per-source favicon.
  ///
  /// Off by default: favicons are fetched from a third-party service
  /// (Google's favicon endpoint), which makes a network request per host and
  /// discloses the cited hosts to that service. Enable it only when that
  /// trade-off is acceptable; chips always fall back to a link glyph offline.
  final bool showFavicons;

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
        for (var i = 0; i < visible.length; i++)
          _SourceChip(
            index: i + 1,
            label: visible[i].title ?? visible[i].url.host,
            url: widget.showFavicons ? visible[i].url : null,
            theme: theme,
            onTap: widget.onTap == null
                ? null
                : () {
                    aiLightHaptic(theme);
                    widget.onTap!(visible[i]);
                  },
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

class _SourceChip extends StatefulWidget {
  const _SourceChip({
    required this.label,
    required this.theme,
    required this.onTap,
    this.index,
    this.url,
    this.icon = Icons.link,
  });

  final String label;
  final AiThemeExtension theme;
  final VoidCallback? onTap;

  /// 1-based citation index, shown as a leading badge. Null for the toggle.
  final int? index;

  /// The source URL, used to fetch a favicon. Null falls back to [icon].
  final Uri? url;
  final IconData icon;

  @override
  State<_SourceChip> createState() => _SourceChipState();
}

class _SourceChipState extends State<_SourceChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final fg = theme.assistantTextColor;
    return Material(
      // Subtle hover lift: blend toward the border color on pointer-over.
      color: _hovered
          ? Color.lerp(theme.assistantBubbleColor, theme.borderColor, 0.5)
          : theme.assistantBubbleColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hovered = h),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.index != null) ...[
                _IndexBadge(index: widget.index!, theme: theme),
                const SizedBox(width: 6),
              ],
              if (widget.url != null)
                _Favicon(url: widget.url!, fallback: widget.icon, color: fg)
              else
                Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small numeric badge for a citation's index.
class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index, required this.theme});

  final int index;
  final AiThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$index',
        textAlign: TextAlign.center,
        style: theme.codeStyle.copyWith(
          fontSize: 11,
          height: 1.3,
          color: theme.assistantTextColor,
        ),
      ),
    );
  }
}

/// Best-effort favicon for [url]'s host, degrading to [fallback] on any error
/// (offline, blocked, unknown host) so the chip always renders something.
class _Favicon extends StatelessWidget {
  const _Favicon({
    required this.url,
    required this.fallback,
    required this.color,
  });

  final Uri url;
  final IconData fallback;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final host = url.host;
    final icon = Icon(fallback, size: 14, color: color);
    if (host.isEmpty) return icon;
    final src = Uri.https('www.google.com', '/s2/favicons', {
      'domain': host,
      'sz': '32',
    });
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Image.network(
        src.toString(),
        width: 14,
        height: 14,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => icon,
        // Avoid a flash of broken layout while loading: keep the fallback until
        // the first frame is available.
        frameBuilder: (_, child, frame, ___) => frame == null ? icon : child,
      ),
    );
  }
}

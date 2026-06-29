import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// An approve/deny card for actions an agent wants to take (running a tool,
/// sending an email, making a purchase) — the human-in-the-loop gate.
class AiConfirmation extends StatelessWidget {
  /// Creates a confirmation card.
  const AiConfirmation({
    super.key,
    required this.title,
    this.description,
    this.confirmLabel,
    this.denyLabel,
    this.onConfirm,
    this.onDeny,
    this.icon = Icons.shield_outlined,
  });

  /// The action being confirmed.
  final String title;

  /// Optional supporting detail.
  final String? description;

  /// Label for the confirm button. Defaults to the localized "Allow".
  final String? confirmLabel;

  /// Label for the deny button. Defaults to the localized "Deny".
  final String? denyLabel;

  /// Called when the user approves.
  final VoidCallback? onConfirm;

  /// Called when the user denies.
  final VoidCallback? onDeny;

  /// Leading icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final l = AiLocalizations.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textStyle.copyWith(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: theme.textStyle.copyWith(
                color: color?.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Button(
                  label: denyLabel ?? l.deny,
                  onTap: onDeny,
                  filled: false,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Button(
                  label: confirmLabel ?? l.allow,
                  onTap: onConfirm,
                  filled: true,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.onTap,
    required this.filled,
    required this.theme,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final AiThemeExtension theme;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      // A confirmation gate must be keyboard- and focus-reachable (desktop/web)
      // — Material + InkWell give focus traversal, Enter/Space, hover, ripple.
      child: Material(
        color: filled ? theme.accentColor : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: filled ? BorderSide.none : BorderSide(color: theme.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            child: Text(
              label,
              style: theme.textStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled
                    ? theme.onAccentColor
                    : DefaultTextStyle.of(context).style.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

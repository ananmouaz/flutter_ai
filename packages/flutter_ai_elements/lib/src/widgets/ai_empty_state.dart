import 'package:flutter/material.dart';

/// A centered placeholder shown when a conversation has no messages yet.
class AiEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const AiEmptyState({
    super.key,
    this.title = 'Start the conversation',
    this.subtitle,
    this.icon = Icons.chat_bubble_outline,
  });

  /// The primary headline.
  final String title;

  /// Optional supporting line beneath the title.
  final String? subtitle;

  /// The icon shown above the title.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color?.withValues(
          alpha: 0.6,
        );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

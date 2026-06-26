import 'package:flutter/material.dart';

/// An inline banner surfacing an error, with optional retry and dismiss.
///
/// Pair it with a controller's `error`/`status` to show failures without a
/// modal interruption.
class AiErrorBanner extends StatelessWidget {
  /// Creates an error banner displaying [message].
  const AiErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
  });

  /// The error text to display.
  final String message;

  /// Called when the user taps Retry. Hidden if `null`.
  final VoidCallback? onRetry;

  /// Called when the user dismisses the banner. Hidden if `null`.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    const errorColor = Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: errorColor),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: errorColor,
              onPressed: onDismiss,
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A monospace code block with a header showing the language and a copy button.
///
/// A useful building block for a custom `AiTextRenderer` that wants to present
/// fenced code distinctly from prose.
class AiCodeBlock extends StatelessWidget {
  /// Creates a code block for [code].
  const AiCodeBlock({super.key, required this.code, this.language});

  /// The source code to display.
  final String code;

  /// An optional language label (for example `dart`).
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    const background = Color(0xFF1E1E1E);
    const foreground = Color(0xFFE6E6E6);
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  language ?? 'code',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.copy, size: 16, color: Color(0xFF9CA3AF)),
                tooltip: 'Copy',
                onPressed: () => unawaited(
                  Clipboard.setData(ClipboardData(text: code)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: SelectableText(
                code,
                style: theme.codeStyle.copyWith(color: foreground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

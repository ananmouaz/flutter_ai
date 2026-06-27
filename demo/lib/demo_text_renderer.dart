import 'package:flutter/widgets.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// A small text renderer that splits prose from fenced ```code``` blocks and
/// renders the code with [AiCodeBlock]. Demonstrates how a host injects richer
/// rendering via `AiTextRenderer` without changing the package.
class DemoTextRenderer implements AiTextRenderer {
  /// Creates the renderer.
  const DemoTextRenderer();

  @override
  Widget render(String text, {required bool isStreaming}) {
    if (!text.contains('```')) return Text(text);

    // Segments alternate prose / code / prose / code ...
    final segments = text.split('```');
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (i.isEven) {
        final prose = seg.trim();
        if (prose.isNotEmpty) children.add(Text(prose));
      } else {
        final newline = seg.indexOf('\n');
        final lang = newline == -1 ? '' : seg.substring(0, newline).trim();
        final code = newline == -1 ? seg : seg.substring(newline + 1);
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AiCodeBlock(
              code: code.trimRight(),
              language: lang.isEmpty ? null : lang,
            ),
          ),
        );
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          children[i],
        ],
      ],
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';

/// A `TextRenderer` that produces a Flutter [Widget] — the rendering seam used
/// throughout the UI.
///
/// Inject a custom implementation (for example a Markdown or LaTeX renderer)
/// wherever a renderer is accepted. The default is [PlainTextRenderer].
typedef AiTextRenderer = TextRenderer<Widget>;

/// The default renderer: emits a plain [Text] widget.
///
/// It intentionally sets no color or size so the surrounding `DefaultTextStyle`
/// (driven by the active theme and message role) governs appearance. Swap in a
/// richer renderer for Markdown, code highlighting, or LaTeX.
class PlainTextRenderer implements AiTextRenderer {
  /// Creates a plain-text renderer.
  const PlainTextRenderer();

  @override
  Widget render(String text, {required bool isStreaming}) => Text(text);
}

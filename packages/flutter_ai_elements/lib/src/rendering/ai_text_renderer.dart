import 'package:flutter/widgets.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';

/// A `TextRenderer` that produces a Flutter [Widget] — the rendering seam used
/// throughout the UI.
///
/// The widgets default to `MarkdownTextRenderer` (Markdown, incl. fenced code
/// blocks). Inject [PlainTextRenderer] for raw text, or a custom implementation
/// (for example a LaTeX renderer) wherever a renderer is accepted.
typedef AiTextRenderer = TextRenderer<Widget>;

/// A renderer that emits a plain [Text] widget (opt in; the widgets default to
/// `MarkdownTextRenderer`).
///
/// It intentionally sets no color or size so the surrounding `DefaultTextStyle`
/// (driven by the active theme and message role) governs appearance. Use it when
/// you want raw, unformatted text instead of the default Markdown rendering.
class PlainTextRenderer implements AiTextRenderer {
  /// Creates a plain-text renderer.
  const PlainTextRenderer();

  @override
  Widget render(String text, {required bool isStreaming}) => Text(text);
}

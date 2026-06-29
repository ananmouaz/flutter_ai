import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/rendering/ai_text_renderer.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';
import 'package:flutter_ai_elements/src/widgets/ai_animated_response.dart';
import 'package:flutter_ai_elements/src/widgets/ai_code_block.dart';

/// Renders a useful subset of Markdown — headings, bold/italic, inline code,
/// fenced code blocks, ordered/unordered lists, blockquotes, and links — with
/// **no external dependency**.
///
/// This is the content renderer for assistant answers. Inline links are styled
/// always and become tappable when [onLinkTap] is provided.
class AiResponse extends StatefulWidget {
  /// Creates a Markdown response from [text].
  const AiResponse({
    super.key,
    required this.text,
    this.onLinkTap,
    this.codeHighlighter,
  });

  /// The Markdown source to render.
  final String text;

  /// Called when a link is tapped. If `null`, links render but aren't tappable.
  final void Function(Uri url)? onLinkTap;

  /// Optional syntax highlighter for fenced code blocks. When `null`, code
  /// renders as plain monospace.
  final CodeHighlighter? codeHighlighter;

  @override
  State<AiResponse> createState() => _AiResponseState();
}

class _AiResponseState extends State<AiResponse> {
  // Heading font sizes by level; hoisted so we don't rebuild the map per block.
  static const Map<int, double> _headingSizes = {1: 24.0, 2: 20.0, 3: 17.0};

  // Matches an alphanumeric char; used to skip intraword `_` emphasis.
  static final RegExp _intraword = RegExp(r'[A-Za-z0-9]');

  final List<TapGestureRecognizer> _recognizers = [];

  // The parsed/built content, computed once per unique (text, onLinkTap) — never
  // in build(). Recognizers are created here and disposed when text changes.
  List<_Block>? _blocks;

  // The theme/base style the cached widget was built against. If the inherited
  // style changes we re-resolve in build() without re-parsing the Markdown.
  AiThemeExtension? _builtTheme;
  TextStyle? _builtBase;
  Widget? _built;

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  // Parses the Markdown source once and caches the block list. Recognizers from
  // the previous parse are disposed first. Does NOT build widgets (those depend
  // on the inherited theme, resolved lazily in build()).
  void _parse() {
    _disposeRecognizers();
    _blocks = _parseBlocks(widget.text);
    // Invalidate the built widget so it's rebuilt against the current theme.
    _built = null;
    _builtTheme = null;
    _builtBase = null;
  }

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(AiResponse oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-parse (and rebuild recognizers) only when the inputs that affect them
    // change — never every frame.
    if (oldWidget.text != widget.text ||
        oldWidget.onLinkTap != widget.onLinkTap ||
        oldWidget.codeHighlighter != widget.codeHighlighter) {
      _parse();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final base = DefaultTextStyle.of(context).style.merge(theme.textStyle);

    // Return the cached widget unless the inherited theme/base style changed.
    if (_built != null && theme == _builtTheme && base == _builtBase) {
      return _built!;
    }

    final blocks = _blocks!;
    final built = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildBlock(blocks[i], theme, base),
        ],
      ],
    );
    _built = built;
    _builtTheme = theme;
    _builtBase = base;
    return built;
  }

  Widget _buildBlock(_Block block, AiThemeExtension theme, TextStyle base) {
    switch (block.type) {
      case _BlockType.heading:
        final style = base.copyWith(
          fontSize: _headingSizes[block.level] ?? 16,
          fontWeight: FontWeight.w700,
          height: 1.3,
        );
        return Text.rich(TextSpan(children: _inline(block.text, style, theme)));
      case _BlockType.code:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: AiCodeBlock(
            code: block.text,
            language: block.language,
            highlighter: widget.codeHighlighter,
          ),
        );
      case _BlockType.bullet:
      case _BlockType.ordered:
        final isTask = block.checks.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < block.items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: isTask
                          ? Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                block.checks[i]
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 16,
                                color: block.checks[i]
                                    ? theme.successColor
                                    : theme.borderColor,
                              ),
                            )
                          : Text(
                              block.type == _BlockType.ordered
                                  ? '${i + 1}.'
                                  : '•',
                              style: base,
                            ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: _inline(block.items[i], base, theme),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case _BlockType.rule:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, thickness: 1, color: theme.borderColor),
        );
      case _BlockType.quote:
        return Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.borderColor, width: 3),
            ),
          ),
          child: Text.rich(
            TextSpan(
              children: _inline(
                block.text,
                base.copyWith(color: base.color?.withValues(alpha: 0.7)),
                theme,
              ),
            ),
          ),
        );
      case _BlockType.table:
        return _buildTable(block.rows, theme, base);
      case _BlockType.paragraph:
        return Text.rich(TextSpan(children: _inline(block.text, base, theme)));
    }
  }

  Widget _buildTable(
    List<List<String>> rows,
    AiThemeExtension theme,
    TextStyle base,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = rows.first.length;
    final headerStyle = base.copyWith(fontWeight: FontWeight.w700);
    // Horizontal scroll keeps wide tables from overflowing the bubble.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.symmetric(
              inside: BorderSide(color: theme.borderColor),
            ),
            children: [
              for (var r = 0; r < rows.length; r++)
                TableRow(
                  decoration: BoxDecoration(
                    color: r == 0 ? theme.assistantBubbleColor : null,
                  ),
                  children: [
                    for (var c = 0; c < cols; c++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: _inline(
                              c < rows[r].length ? rows[r][c] : '',
                              r == 0 ? headerStyle : base,
                              theme,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Inline parsing: **bold**, *italic*/_italic_, `code`, [text](url).
  List<InlineSpan> _inline(
    String text,
    TextStyle base,
    AiThemeExtension theme,
  ) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    var i = 0;

    void flush() {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString(), style: base));
        buffer.clear();
      }
    }

    while (i < text.length) {
      if (text.startsWith('**', i)) {
        final end = text.indexOf('**', i + 2);
        if (end != -1) {
          flush();
          spans.addAll(
            _inline(
              text.substring(i + 2, end),
              base.copyWith(fontWeight: FontWeight.w700),
              theme,
            ),
          );
          i = end + 2;
          continue;
        }
      }
      if (text.startsWith('~~', i)) {
        final end = text.indexOf('~~', i + 2);
        if (end != -1) {
          flush();
          spans.addAll(
            _inline(
              text.substring(i + 2, end),
              base.copyWith(
                decoration: TextDecoration.lineThrough,
                decorationColor: base.color,
              ),
              theme,
            ),
          );
          i = end + 2;
          continue;
        }
      }
      final char = text[i];
      if (char == '`') {
        final end = text.indexOf('`', i + 1);
        if (end != -1) {
          flush();
          spans.add(
            TextSpan(
              text: text.substring(i + 1, end),
              style: theme.codeStyle.copyWith(color: base.color),
            ),
          );
          i = end + 1;
          continue;
        }
      }
      if (char == '[') {
        final close = text.indexOf(']', i + 1);
        if (close != -1 && close + 1 < text.length && text[close + 1] == '(') {
          final urlEnd = text.indexOf(')', close + 2);
          if (urlEnd != -1) {
            flush();
            spans.add(
              _linkSpan(
                text.substring(i + 1, close),
                text.substring(close + 2, urlEnd),
                base,
                theme,
              ),
            );
            i = urlEnd + 1;
            continue;
          }
        }
      }
      if (char == '*' || char == '_') {
        final end = text.indexOf(char, i + 1);
        // Avoid false emphasis on prose: require non-space right after the
        // opening marker (so "2 * 3" isn't italic), and for `_` skip intraword
        // use (so identifiers like `snake_case` aren't italicized).
        final prev = i > 0 ? text[i - 1] : ' ';
        final intraword = char == '_' && _intraword.hasMatch(prev);
        if (!intraword && end > i + 1 && text[i + 1] != ' ') {
          flush();
          spans.addAll(
            _inline(
              text.substring(i + 1, end),
              base.copyWith(fontStyle: FontStyle.italic),
              theme,
            ),
          );
          i = end + 1;
          continue;
        }
      }
      buffer.write(char);
      i++;
    }
    flush();
    return spans;
  }

  InlineSpan _linkSpan(
    String label,
    String url,
    TextStyle base,
    AiThemeExtension theme,
  ) {
    final style = base.copyWith(
      color: theme.linkColor,
      decoration: TextDecoration.underline,
    );
    final onTap = widget.onLinkTap;
    if (onTap == null) return TextSpan(text: label, style: style);
    final recognizer = TapGestureRecognizer()
      ..onTap = () => onTap(Uri.parse(url));
    _recognizers.add(recognizer);
    return TextSpan(text: label, style: style, recognizer: recognizer);
  }
}

/// An [AiTextRenderer] that renders Markdown via [AiResponse]. The default
/// renderer for assistant content.
class MarkdownTextRenderer implements AiTextRenderer {
  /// Creates a Markdown renderer.
  const MarkdownTextRenderer({this.onLinkTap, this.codeHighlighter});

  /// Forwarded to [AiResponse.onLinkTap].
  final void Function(Uri url)? onLinkTap;

  /// Forwarded to [AiResponse.codeHighlighter] for the completed message.
  final CodeHighlighter? codeHighlighter;

  @override
  Widget render(String text, {required bool isStreaming}) => isStreaming
      ? AiAnimatedResponse(text: text, onLinkTap: onLinkTap)
      : AiResponse(
          text: text,
          onLinkTap: onLinkTap,
          codeHighlighter: codeHighlighter,
        );
}

enum _BlockType {
  paragraph,
  heading,
  code,
  bullet,
  ordered,
  quote,
  table,
  rule
}

class _Block {
  _Block.paragraph(this.text)
      : type = _BlockType.paragraph,
        level = 0,
        language = null,
        items = const [],
        checks = const [],
        rows = const [];
  _Block.heading(this.level, this.text)
      : type = _BlockType.heading,
        language = null,
        items = const [],
        checks = const [],
        rows = const [];
  _Block.code(this.text, this.language)
      : type = _BlockType.code,
        level = 0,
        items = const [],
        checks = const [],
        rows = const [];
  _Block.quote(this.text)
      : type = _BlockType.quote,
        level = 0,
        language = null,
        items = const [],
        checks = const [],
        rows = const [];
  _Block.list(this.type, this.items, {this.checks = const []})
      : level = 0,
        language = null,
        text = '',
        rows = const [];
  _Block.rule()
      : type = _BlockType.rule,
        level = 0,
        language = null,
        text = '',
        items = const [],
        checks = const [],
        rows = const [];
  _Block.table(this.rows)
      : type = _BlockType.table,
        level = 0,
        language = null,
        text = '',
        items = const [],
        checks = const [];

  final _BlockType type;
  final String text;
  final int level;
  final String? language;
  final List<String> items;

  /// For task lists: per-item checkbox state (`true`/`false`), or empty for a
  /// plain bullet/ordered list. Parallel to [items].
  final List<bool> checks;

  /// Table cells, first row being the header. Empty for non-tables.
  final List<List<String>> rows;
}

List<_Block> _parseBlocks(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <_Block>[];
  var i = 0;

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      i++;
      continue;
    }

    // Fenced code block.
    if (trimmed.startsWith('```')) {
      final language = trimmed.substring(3).trim();
      final codeLines = <String>[];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.add(lines[i]);
        i++;
      }
      if (i < lines.length) i++; // skip closing fence
      blocks.add(
        _Block.code(codeLines.join('\n'), language.isEmpty ? null : language),
      );
      continue;
    }

    // Horizontal rule: three or more -, * or _ (optionally spaced), alone.
    if (RegExp(r'^(?:-\s*){3,}$|^(?:\*\s*){3,}$|^(?:_\s*){3,}$')
        .hasMatch(trimmed)) {
      blocks.add(_Block.rule());
      i++;
      continue;
    }

    // Heading.
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      blocks.add(_Block.heading(heading.group(1)!.length, heading.group(2)!));
      i++;
      continue;
    }

    // GFM table: a header row, a `---|---` separator, then body rows.
    if (_isTableHeaderAt(lines, i)) {
      final rows = <List<String>>[_splitTableRow(trimmed)];
      i += 2; // header + separator
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          lines[i].contains('|')) {
        rows.add(_splitTableRow(lines[i].trim()));
        i++;
      }
      blocks.add(_Block.table(rows));
      continue;
    }

    // Blockquote (consecutive > lines).
    if (trimmed.startsWith('>')) {
      final quoteLines = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        quoteLines.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
        i++;
      }
      blocks.add(_Block.quote(quoteLines.join(' ')));
      continue;
    }

    // Task list (GFM checkboxes): `- [ ] todo` / `- [x] done`.
    final task = RegExp(r'^[-*+]\s+\[([ xX])\]\s+');
    if (task.hasMatch(trimmed)) {
      final items = <String>[];
      final checks = <bool>[];
      while (i < lines.length && task.hasMatch(lines[i].trim())) {
        final t = lines[i].trim();
        final m = task.firstMatch(t)!;
        checks.add(m.group(1) != ' ');
        items.add(t.substring(m.end));
        i++;
      }
      blocks.add(_Block.list(_BlockType.bullet, items, checks: checks));
      continue;
    }

    // Unordered list.
    if (RegExp(r'^[-*+]\s+').hasMatch(trimmed)) {
      final items = <String>[];
      while (i < lines.length &&
          RegExp(r'^[-*+]\s+').hasMatch(lines[i].trim()) &&
          !task.hasMatch(lines[i].trim())) {
        items.add(lines[i].trim().replaceFirst(RegExp(r'^[-*+]\s+'), ''));
        i++;
      }
      blocks.add(_Block.list(_BlockType.bullet, items));
      continue;
    }

    // Ordered list.
    if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
      final items = <String>[];
      while (
          i < lines.length && RegExp(r'^\d+\.\s+').hasMatch(lines[i].trim())) {
        items.add(lines[i].trim().replaceFirst(RegExp(r'^\d+\.\s+'), ''));
        i++;
      }
      blocks.add(_Block.list(_BlockType.ordered, items));
      continue;
    }

    // Paragraph (consecutive non-blank, non-special lines).
    //
    // The first line here was already rejected by every block detector above,
    // so it is genuinely paragraph text — always consume it. Only *subsequent*
    // lines may break the paragraph. Gating the break on a non-empty paragraph
    // guarantees `i` advances every outer iteration, so a partial stream that
    // ends mid-construct (e.g. a lone `#` before its space arrives) can never
    // spin this loop forever.
    final paragraph = <String>[];
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      final t = lines[i].trim();
      if (paragraph.isNotEmpty &&
          (t.startsWith('```') ||
              RegExp(r'^#{1,6}\s+').hasMatch(t) ||
              t.startsWith('>') ||
              _isTableHeaderAt(lines, i) ||
              RegExp(r'^(?:-\s*){3,}$|^(?:\*\s*){3,}$|^(?:_\s*){3,}$')
                  .hasMatch(t) ||
              RegExp(r'^[-*+]\s+').hasMatch(t) ||
              RegExp(r'^\d+\.\s+').hasMatch(t))) {
        break;
      }
      paragraph.add(t);
      i++;
    }
    if (paragraph.isNotEmpty) blocks.add(_Block.paragraph(paragraph.join(' ')));
  }

  return blocks;
}

/// True if line [i] is a table header (contains a pipe) followed by a
/// `---|:--:` separator row.
bool _isTableHeaderAt(List<String> lines, int i) {
  if (i + 1 >= lines.length) return false;
  if (!lines[i].contains('|')) return false;
  final sep = lines[i + 1].trim();
  return sep.contains('-') &&
      sep.contains('|') &&
      RegExp(r'^[\s|:-]+$').hasMatch(sep);
}

/// Splits a `| a | b |` row into trimmed cells, dropping the outer pipes.
List<String> _splitTableRow(String line) {
  var s = line.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|')) s = s.substring(0, s.length - 1);
  return s.split('|').map((c) => c.trim()).toList();
}

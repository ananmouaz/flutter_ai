import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

/// A demo [CodeHighlighter] backed by the `highlight` package, mapping token
/// classes to a VS Code–dark-ish palette. Returns `null` (plain monospace) when
/// the language is unknown or parsing fails, so rendering never breaks.
List<TextSpan>? demoCodeHighlighter(
  String code,
  String? language,
  TextStyle base,
) {
  try {
    final result = (language != null && language.isNotEmpty)
        ? highlight.parse(code, language: language)
        : highlight.parse(code, autoDetection: true);
    final nodes = result.nodes;
    if (nodes == null) return null;
    return [for (final node in nodes) _span(node, base)];
  } catch (_) {
    return null; // unknown grammar → fall back to plain monospace
  }
}

const _tokenColors = <String, Color>{
  'keyword': Color(0xFFC586C0),
  'built_in': Color(0xFF4EC9B0),
  'type': Color(0xFF4EC9B0),
  'class': Color(0xFF4EC9B0),
  'title': Color(0xFFDCDCAA),
  'function': Color(0xFFDCDCAA),
  'string': Color(0xFFCE9178),
  'number': Color(0xFFB5CEA8),
  'symbol': Color(0xFFB5CEA8),
  'literal': Color(0xFF569CD6),
  'comment': Color(0xFF6A9955),
  'meta': Color(0xFF9CDCFE),
  'attr': Color(0xFF9CDCFE),
};

TextSpan _span(Node node, TextStyle base) {
  final color = node.className == null ? null : _tokenColors[node.className!];
  final style = color == null ? base : base.copyWith(color: color);
  final value = node.value;
  if (value != null) return TextSpan(text: value, style: style);
  final children = node.children ?? const <Node>[];
  return TextSpan(
    style: style,
    children: [for (final child in children) _span(child, base)],
  );
}

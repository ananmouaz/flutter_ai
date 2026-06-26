import 'dart:convert';

/// Accumulates a JSON document that arrives in fragments and parses it
/// tolerantly while still incomplete.
///
/// Tool-call arguments stream from the model as a sequence of partial JSON
/// strings. A naive `jsonDecode` of the buffer throws until the very last
/// fragment lands, which makes live rendering impossible. [JsonAccumulator]
/// instead repairs the partial buffer — closing open strings and containers and
/// dropping any trailing incomplete token — so callers can show a best-effort
/// view at every step, then validate strictly once the document is complete.
///
/// The repair is conservative: it never throws and never invents data. When a
/// trailing value cannot be completed safely it is dropped rather than guessed,
/// so [parsePartial] only ever returns a prefix of the eventual document.
class JsonAccumulator {
  final StringBuffer _buffer = StringBuffer();
  Object? _lastPartial;

  /// Appends a fragment to the buffer.
  void add(String fragment) => _buffer.write(fragment);

  /// Clears the buffer and cached partial result.
  void reset() {
    _buffer.clear();
    _lastPartial = null;
  }

  /// The raw accumulated text.
  String get raw => _buffer.toString();

  /// Whether nothing has been accumulated yet.
  bool get isEmpty => _buffer.isEmpty;

  /// Strictly parses the buffer, returning `null` if it is not yet valid JSON.
  ///
  /// Never throws — a parse failure simply yields `null`.
  Object? tryParseComplete() {
    final source = raw;
    if (source.trim().isEmpty) return null;
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  /// Returns a best-effort decode of the (possibly partial) buffer.
  ///
  /// If the buffer is already valid JSON it is returned as-is. Otherwise the
  /// buffer is repaired and decoded; if even the repair cannot be parsed, the
  /// most recent successful partial is returned (or `null` if there is none).
  Object? parsePartial() {
    final source = raw;
    if (source.trim().isEmpty) return _lastPartial;

    final strict = tryParseComplete();
    if (strict != null) {
      _lastPartial = strict;
      return strict;
    }

    final repaired = _repair(source);
    if (repaired != null) {
      try {
        final value = jsonDecode(repaired);
        _lastPartial = value;
        return value;
      } on FormatException {
        // Fall through to the cached partial.
      }
    }
    return _lastPartial;
  }
}

const int _quote = 0x22; //  "
const int _backslash = 0x5c; // \
const int _colon = 0x3a; //  :
const int _comma = 0x2c; //  ,
const int _openBrace = 0x7b; //  {
const int _closeBrace = 0x7d; //  }
const int _openBracket = 0x5b; //  [
const int _closeBracket = 0x5d; //  ]
const int _space = 0x20;
const int _tab = 0x09;
const int _newline = 0x0a;
const int _return = 0x0d;

bool _isWhitespace(int c) =>
    c == _space || c == _tab || c == _newline || c == _return;

// Parser states for the repair scanner.
const int _expectValue = 0; // start of value (array elem, after ':', after '[')
const int _afterValue = 1; // a complete value just ended (a safe cut point)
const int _expectKey = 2; // start of object member (a key string, or '}')
const int _expectColon = 3; // a key just ended, ':' must follow

/// Completes a truncated JSON [source] into a valid JSON string, or returns
/// `null` if no safe completion exists.
///
/// Walks the document tracking the open-container stack and a small state
/// machine. It remembers the latest position at which the document could be
/// legally closed (a "safe cut") together with the container stack there, then
/// truncates to that point and appends the matching closers. Anything after the
/// last safe cut — an unterminated string, a dangling `"key":`, a half-written
/// number — is discarded.
String? _repair(String source) {
  final stack = <int>[]; // _openBrace / _openBracket, outermost first
  var state = _expectValue;
  var safeLen = -1;
  var safeStack = const <int>[];

  void markSafe(int length) {
    safeLen = length;
    safeStack = List<int>.of(stack);
  }

  var i = 0;
  final length = source.length;
  scan:
  while (i < length) {
    final c = source.codeUnitAt(i);
    if (_isWhitespace(c)) {
      i++;
      continue;
    }

    switch (state) {
      case _expectKey:
        if (c == _closeBrace) {
          stack.removeLast();
          state = _afterValue;
          i++;
          markSafe(i);
        } else if (c == _quote) {
          final end = _scanString(source, i);
          if (end == -1) break scan; // incomplete key
          i = end;
          state = _expectColon;
        } else {
          break scan;
        }

      case _expectColon:
        if (c == _colon) {
          state = _expectValue;
          i++;
        } else {
          break scan;
        }

      case _expectValue:
        if (c == _openBrace) {
          stack.add(_openBrace);
          state = _expectKey;
          i++;
          markSafe(i); // an empty object can be closed
        } else if (c == _openBracket) {
          stack.add(_openBracket);
          state = _expectValue;
          i++;
          markSafe(i); // an empty array can be closed
        } else if (c == _closeBracket &&
            stack.isNotEmpty &&
            stack.last == _openBracket) {
          stack.removeLast(); // empty array: "[]"
          state = _afterValue;
          i++;
          markSafe(i);
        } else if (c == _quote) {
          final end = _scanString(source, i);
          if (end == -1) break scan; // incomplete value string
          i = end;
          state = _afterValue;
          markSafe(i);
        } else {
          // A number or keyword. If it runs to the end of the buffer we treat
          // it as complete (best effort); should it turn out to be a partial
          // token like "tru", the repaired string simply fails to decode and
          // the caller keeps its last good partial.
          i = _scanLiteral(source, i);
          state = _afterValue;
          markSafe(i);
        }

      case _afterValue:
        if (c == _comma) {
          state = (stack.isNotEmpty && stack.last == _openBrace)
              ? _expectKey
              : _expectValue;
          i++;
        } else if (c == _closeBrace &&
            stack.isNotEmpty &&
            stack.last == _openBrace) {
          stack.removeLast();
          i++;
          markSafe(i);
        } else if (c == _closeBracket &&
            stack.isNotEmpty &&
            stack.last == _openBracket) {
          stack.removeLast();
          i++;
          markSafe(i);
        } else {
          break scan;
        }
    }
  }

  if (safeLen < 0) return null;
  final buffer = StringBuffer(source.substring(0, safeLen));
  for (var k = safeStack.length - 1; k >= 0; k--) {
    buffer.writeCharCode(
      safeStack[k] == _openBrace ? _closeBrace : _closeBracket,
    );
  }
  return buffer.toString();
}

/// Returns the index just past the closing quote of the string starting at
/// [start], or `-1` if the string is unterminated.
int _scanString(String source, int start) {
  var i = start + 1; // skip the opening quote
  final length = source.length;
  while (i < length) {
    final c = source.codeUnitAt(i);
    if (c == _backslash) {
      i += 2; // skip the escaped character
      continue;
    }
    if (c == _quote) return i + 1;
    i++;
  }
  return -1;
}

/// Returns the index just past a literal (number, `true`, `false`, `null`)
/// starting at [start].
///
/// Scanning ends at the first structural delimiter or whitespace, or at the end
/// of [source] if the literal is the final token.
int _scanLiteral(String source, int start) {
  var i = start;
  final length = source.length;
  while (i < length) {
    final c = source.codeUnitAt(i);
    if (_isWhitespace(c) ||
        c == _comma ||
        c == _closeBrace ||
        c == _closeBracket) {
      return i;
    }
    i++;
  }
  return length;
}

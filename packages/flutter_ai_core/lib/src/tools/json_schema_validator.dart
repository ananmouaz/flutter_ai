/// A tiny, dependency-free validator for the subset of JSON Schema that LLM
/// tool/function declarations actually use.
///
/// This is intentionally *not* a full JSON Schema implementation. It covers the
/// keywords providers emit for tool parameters — `type`, `properties`,
/// `required`, `items`, `enum`, `additionalProperties: false`, and the common
/// numeric/string/array bounds — which is enough to catch the malformed
/// arguments a model occasionally produces and to feed an actionable error back
/// so it can correct itself.
///
/// [validateJsonSchema] returns a list of human-readable violation messages;
/// an empty list means the value satisfies the schema. Unknown keywords are
/// ignored (treated as "no constraint") rather than rejected, so a richer
/// server-side schema never produces false negatives here.
library;

/// Validates [value] against [schema], returning a list of violation messages
/// (empty when valid). [path] names the root in messages (defaults to `args`).
List<String> validateJsonSchema(
  Object? value,
  Map<String, Object?> schema, {
  String path = 'args',
}) {
  final errors = <String>[];
  _validate(value, schema, path, errors);
  return errors;
}

void _validate(
  Object? value,
  Map<String, Object?> schema,
  String path,
  List<String> errors,
) {
  // An empty schema imposes no constraints.
  if (schema.isEmpty) return;

  final type = schema['type'];
  if (type != null && !_typeMatches(value, type)) {
    errors.add('$path: expected type $type but got ${_typeName(value)}');
    // A type mismatch makes deeper checks meaningless.
    return;
  }

  final enumValues = schema['enum'];
  if (enumValues is List && !enumValues.any((e) => _deepEq(e, value))) {
    errors.add('$path: must be one of $enumValues');
  }

  switch (value) {
    case final num n:
      _validateNumber(n, schema, path, errors);
    case final String s:
      _validateString(s, schema, path, errors);
    case final List<Object?> list:
      _validateArray(list, schema, path, errors);
    case final Map<Object?, Object?> map:
      _validateObject(map.cast(), schema, path, errors);
  }
}

void _validateNumber(
  num n,
  Map<String, Object?> schema,
  String path,
  List<String> errors,
) {
  final min = schema['minimum'];
  if (min is num && n < min) errors.add('$path: must be >= $min');
  final max = schema['maximum'];
  if (max is num && n > max) errors.add('$path: must be <= $max');
}

void _validateString(
  String s,
  Map<String, Object?> schema,
  String path,
  List<String> errors,
) {
  final minLen = schema['minLength'];
  if (minLen is int && s.length < minLen) {
    errors.add('$path: must be at least $minLen characters');
  }
  final maxLen = schema['maxLength'];
  if (maxLen is int && s.length > maxLen) {
    errors.add('$path: must be at most $maxLen characters');
  }
}

void _validateArray(
  List<Object?> list,
  Map<String, Object?> schema,
  String path,
  List<String> errors,
) {
  final minItems = schema['minItems'];
  if (minItems is int && list.length < minItems) {
    errors.add('$path: must have at least $minItems items');
  }
  final maxItems = schema['maxItems'];
  if (maxItems is int && list.length > maxItems) {
    errors.add('$path: must have at most $maxItems items');
  }
  final items = schema['items'];
  if (items is Map<String, Object?>) {
    for (var i = 0; i < list.length; i++) {
      _validate(list[i], items, '$path[$i]', errors);
    }
  }
}

void _validateObject(
  Map<String, Object?> map,
  Map<String, Object?> schema,
  String path,
  List<String> errors,
) {
  final required = schema['required'];
  if (required is List) {
    for (final key in required) {
      if (key is String && !map.containsKey(key)) {
        errors.add('$path: missing required property "$key"');
      }
    }
  }

  final properties = schema['properties'];
  if (properties is Map) {
    properties.forEach((key, propSchema) {
      if (propSchema is Map<String, Object?> && map.containsKey(key)) {
        _validate(map[key], propSchema, '$path.$key', errors);
      }
    });
  }

  // additionalProperties: false rejects keys not named in `properties`.
  if (schema['additionalProperties'] == false && properties is Map) {
    final allowed = properties.keys.toSet();
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        errors.add('$path: unexpected property "$key"');
      }
    }
  }
}

bool _typeMatches(Object? value, Object? type) {
  // JSON Schema allows a union of types as a list.
  if (type is List) return type.any((t) => _typeMatches(value, t));
  return switch (type) {
    'object' => value is Map,
    'array' => value is List,
    'string' => value is String,
    'integer' => value is int,
    'number' => value is num,
    'boolean' => value is bool,
    'null' => value == null,
    _ => true, // unknown type keyword: don't constrain
  };
}

String _typeName(Object? value) => switch (value) {
      null => 'null',
      Map() => 'object',
      List() => 'array',
      String() => 'string',
      int() => 'integer',
      num() => 'number',
      bool() => 'boolean',
      _ => value.runtimeType.toString(),
    };

bool _deepEq(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEq(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEq(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

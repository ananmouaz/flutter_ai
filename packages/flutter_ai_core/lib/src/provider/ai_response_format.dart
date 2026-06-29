import 'package:flutter_ai_core/src/internal/equality.dart';

/// Requests structured output constrained to a JSON [schema].
///
/// Providers route this to their native mechanism: OpenAI `response_format`
/// (`json_schema`, [strict]), Gemini `responseSchema`, and Anthropic a forced
/// tool whose input is [schema] (its result is surfaced as the JSON answer). In
/// every case the assistant's text is the JSON object, which you can decode and
/// validate against [schema].
final class AiResponseFormat {
  /// Creates a structured-output request for [schema] (a JSON Schema object).
  const AiResponseFormat({
    required this.schema,
    this.name = 'response',
    this.strict = true,
  });

  /// The JSON Schema the output must conform to.
  final Map<String, Object?> schema;

  /// A short name for the schema (used by providers that require one).
  final String name;

  /// Whether to enforce the schema strictly where the provider supports it.
  final bool strict;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiResponseFormat &&
          other.name == name &&
          other.strict == strict &&
          deepEquals(other.schema, schema));

  @override
  int get hashCode => Object.hash(name, strict, deepHash(schema));

  @override
  String toString() => 'AiResponseFormat(name: $name, strict: $strict)';
}

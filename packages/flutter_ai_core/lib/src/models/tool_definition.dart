import 'package:flutter_ai_core/src/internal/equality.dart';

/// A declaration of a tool the model may call: its name, purpose, and the
/// JSON Schema describing its arguments.
///
/// This is pure data — it carries no executor. The `flutter_ai_tools` package
/// builds on it to add client-side execution. Keeping the declaration in the
/// core lets [provider contracts](LlmProvider) accept tools without depending on
/// the tools package.
final class ToolDefinition {
  /// Creates a tool definition.
  const ToolDefinition({
    required this.name,
    required this.description,
    this.parametersSchema = const {},
  });

  /// Reconstructs a [ToolDefinition] from [json].
  factory ToolDefinition.fromJson(Map<String, Object?> json) => ToolDefinition(
        name: json['name']! as String,
        description: json['description']! as String,
        parametersSchema:
            (json['parametersSchema'] as Map?)?.cast<String, Object?>() ??
                const {},
      );

  /// The tool's unique name, as referenced in tool calls.
  final String name;

  /// A natural-language description the model uses to decide when to call it.
  final String description;

  /// A JSON Schema object describing the tool's arguments.
  final Map<String, Object?> parametersSchema;

  /// Serializes this definition.
  Map<String, Object?> toJson() => {
        'name': name,
        'description': description,
        'parametersSchema': parametersSchema,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolDefinition &&
          other.name == name &&
          other.description == description &&
          deepEquals(other.parametersSchema, parametersSchema));

  @override
  int get hashCode =>
      Object.hash(name, description, deepHash(parametersSchema));

  @override
  String toString() => 'ToolDefinition($name)';
}

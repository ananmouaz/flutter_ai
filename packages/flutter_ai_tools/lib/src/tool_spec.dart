import 'dart:async';

import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Runs a tool's logic given its decoded arguments, returning a JSON-encodable
/// result (or a [Future] of one).
typedef ToolExecutor = FutureOr<Object?> Function(Map<String, Object?> args);

/// A tool the model can call, pairing a [ToolDefinition] with the client-side
/// [execute] logic that fulfills it.
///
/// The declaration half ([name], [description], [parametersSchema]) is what the
/// model sees; [execute] is optional — omit it for tools the server runs.
final class ToolSpec {
  /// Creates a tool specification.
  const ToolSpec({
    required this.name,
    required this.description,
    this.parametersSchema = const {},
    this.execute,
  });

  /// The tool's unique name, referenced in tool calls.
  final String name;

  /// Natural-language description the model uses to decide when to call it.
  final String description;

  /// A JSON Schema object describing the tool's arguments.
  final Map<String, Object?> parametersSchema;

  /// Client-side implementation, or `null` if the tool executes elsewhere.
  final ToolExecutor? execute;

  /// The model-facing declaration for this tool.
  ToolDefinition toDefinition() => ToolDefinition(
        name: name,
        description: description,
        parametersSchema: parametersSchema,
      );

  @override
  String toString() => 'ToolSpec($name)';
}

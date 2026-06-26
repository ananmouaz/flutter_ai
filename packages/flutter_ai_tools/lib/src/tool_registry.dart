import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_tools/src/tool_spec.dart';

/// A collection of [ToolSpec]s that can advertise themselves to a provider and
/// execute incoming tool calls.
///
/// The registry is the optional "auto round-tripping" seam: feed it a
/// [ToolCallPart] and it returns the matching [ToolResultPart], catching any
/// failure as an error result rather than throwing — so a misbehaving tool can
/// never crash the chat loop.
class ToolRegistry {
  /// Creates a registry seeded with [tools].
  ToolRegistry([Iterable<ToolSpec> tools = const []]) {
    for (final tool in tools) {
      register(tool);
    }
  }

  final Map<String, ToolSpec> _tools = {};

  /// Registers [tool], replacing any existing tool with the same name.
  void register(ToolSpec tool) => _tools[tool.name] = tool;

  /// The tool registered under [name], or `null`.
  ToolSpec? operator [](String name) => _tools[name];

  /// Whether no tools are registered.
  bool get isEmpty => _tools.isEmpty;

  /// The model-facing declarations for every registered tool, suitable for
  /// passing to an `LlmProvider`.
  List<ToolDefinition> get definitions =>
      [for (final tool in _tools.values) tool.toDefinition()];

  /// Executes [call] against its registered tool and returns the result.
  ///
  /// If the tool is unknown or has no executor, or if the executor throws, an
  /// error [ToolResultPart] is returned rather than throwing.
  Future<ToolResultPart> run(ToolCallPart call) async {
    final tool = _tools[call.toolName];
    if (tool?.execute == null) {
      return ToolResultPart(
        toolCallId: call.toolCallId,
        result: 'No executor registered for tool "${call.toolName}"',
        isError: true,
      );
    }
    try {
      final result = await tool!.execute!(call.args);
      return ToolResultPart(toolCallId: call.toolCallId, result: result);
    } on Object catch (error) {
      return ToolResultPart(
        toolCallId: call.toolCallId,
        result: error.toString(),
        isError: true,
      );
    }
  }
}

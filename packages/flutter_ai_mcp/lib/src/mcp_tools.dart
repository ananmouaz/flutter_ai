import 'package:flutter_ai_mcp/src/mcp_connection.dart';
import 'package:flutter_ai_tools/flutter_ai_tools.dart';

/// Lists [connection]'s tools and adapts each to a flutter_ai [ToolSpec] whose
/// executor calls back into the MCP server.
///
/// Register the returned specs in a `ToolRegistry` (or pass their
/// `toDefinition()`s to a provider) so MCP tools flow through the same agent
/// loop as native tools:
///
/// ```dart
/// final mcp = await StreamableHttpMcpConnection.connect(baseUrl: '...');
/// final registry = ToolRegistry();
/// for (final spec in await mcpToolSpecs(mcp)) {
///   registry.register(spec);
/// }
/// ```
Future<List<ToolSpec>> mcpToolSpecs(McpConnection connection) async {
  final tools = await connection.listTools();
  return [
    for (final tool in tools)
      ToolSpec(
        name: tool.name,
        description: tool.description,
        parametersSchema: tool.inputSchema,
        execute: (args) => connection.callTool(tool.name, args),
      ),
  ];
}

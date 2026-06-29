/// A tool discovered on an MCP server.
class McpToolInfo {
  /// Creates a tool descriptor.
  const McpToolInfo({
    required this.name,
    this.description = '',
    this.inputSchema = const {},
  });

  /// The tool's name (used in tool calls).
  final String name;

  /// Natural-language description the model uses to decide when to call it.
  final String description;

  /// JSON Schema for the tool's arguments.
  final Map<String, Object?> inputSchema;
}

/// A connection to an MCP server: list its tools and call them.
///
/// Implement this over any transport; `StreamableHttpMcpConnection` is the
/// built-in Streamable-HTTP implementation. Adapt the discovered tools into
/// flutter_ai tools with `mcpToolSpecs`.
abstract interface class McpConnection {
  /// Lists the tools the server exposes.
  Future<List<McpToolInfo>> listTools();

  /// Calls [name] with [arguments] and returns the result (text/JSON content).
  Future<Object?> callTool(String name, Map<String, Object?> arguments);

  /// Closes the connection.
  Future<void> close();
}

import 'package:flutter_ai_mcp/src/mcp_connection.dart';
import 'package:mcp_client/mcp_client.dart';

/// An [McpConnection] over MCP **Streamable HTTP** (the right transport for
/// mobile/web — stdio is desktop-only), backed by `package:mcp_client`.
///
/// ```dart
/// final mcp = await StreamableHttpMcpConnection.connect(
///   baseUrl: 'https://my-mcp-server.example.com',
///   headers: {'Authorization': 'Bearer …'},
/// );
/// final specs = await mcpToolSpecs(mcp); // → flutter_ai ToolSpecs
/// ```
class StreamableHttpMcpConnection implements McpConnection {
  StreamableHttpMcpConnection._(this._client);

  final Client _client;

  /// Connects to the MCP server at [baseUrl] and initializes the session.
  ///
  /// [headers] are sent on every request (e.g. an `Authorization` token).
  /// Throws if the connection or handshake fails.
  static Future<StreamableHttpMcpConnection> connect({
    required String baseUrl,
    Map<String, String> headers = const {},
    String name = 'flutter_ai',
    String version = '0.1.0',
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final result = await McpClient.createAndConnect(
      config: McpClient.simpleConfig(name: name, version: version),
      transportConfig: TransportConfig.streamableHttp(
        baseUrl: baseUrl,
        headers: headers,
        timeout: timeout,
      ),
    );
    final client = result.fold(
      (client) => client,
      (error) => throw StateError('MCP connect failed: $error'),
    );
    return StreamableHttpMcpConnection._(client);
  }

  @override
  Future<List<McpToolInfo>> listTools() async {
    final tools = await _client.listTools();
    return [
      for (final tool in tools)
        McpToolInfo(
          name: tool.name,
          description: tool.description,
          inputSchema: Map<String, Object?>.from(tool.inputSchema),
        ),
    ];
  }

  @override
  Future<Object?> callTool(String name, Map<String, Object?> arguments) async {
    final result = await _client.callTool(name, arguments);
    final text =
        result.content.whereType<TextContent>().map((c) => c.text).join();
    // Surface tool failures as an exception so the registry feeds an error
    // result back to the model (rather than passing the error off as success).
    if (result.isError ?? false) {
      throw McpToolException(
        name,
        text.isEmpty ? 'MCP tool "$name" returned an error' : text,
      );
    }
    // Prefer the server's structured content when present; else the text.
    return result.structuredContent ?? text;
  }

  @override
  Future<void> close() async => _client.disconnect();
}

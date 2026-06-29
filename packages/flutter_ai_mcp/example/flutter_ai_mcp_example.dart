// ignore_for_file: avoid_print
import 'package:flutter_ai_mcp/flutter_ai_mcp.dart';
import 'package:flutter_ai_tools/flutter_ai_tools.dart';

/// Connects to an MCP server over Streamable HTTP, registers its tools, and
/// shows how they become flutter_ai tools for the agent loop.
Future<void> main() async {
  final mcp = await StreamableHttpMcpConnection.connect(
    baseUrl: 'https://my-mcp-server.example.com',
    headers: {'Authorization': 'Bearer <token>'},
  );

  final registry = ToolRegistry();
  for (final spec in await mcpToolSpecs(mcp)) {
    registry.register(spec);
  }

  // registry.definitions → advertise to a provider; wire the agent loop with
  // `UseChatController(onToolCalls: (calls) => Future.wait(calls.map(registry.run)))`
  // and tool calls route back to MCP automatically.
  print('Registered ${registry.definitions.length} MCP tools.');

  await mcp.close();
}

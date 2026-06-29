/// Model Context Protocol (MCP) integration for the `flutter_ai` family.
///
/// Connect to an MCP server (`StreamableHttpMcpConnection`), then adapt its
/// tools into flutter_ai tools with `mcpToolSpecs` so they flow through the
/// agent loop alongside native tools.
library;

export 'package:flutter_ai_tools/flutter_ai_tools.dart' show ToolSpec;

export 'src/mcp_connection.dart';
export 'src/mcp_tools.dart';
export 'src/streamable_http_mcp_connection.dart';

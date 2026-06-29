# Changelog

## 0.1.0

Initial release.

- `McpConnection` / `McpToolInfo` — a transport-agnostic contract for listing
  and calling MCP server tools.
- `StreamableHttpMcpConnection.connect(...)` — connects to an MCP server over
  Streamable HTTP (the right transport for mobile/web), backed by `mcp_client`.
- `mcpToolSpecs(connection)` — adapts discovered MCP tools into flutter_ai
  `ToolSpec`s so they register in a `ToolRegistry` and flow through the agent
  loop alongside native tools.

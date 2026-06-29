# Changelog

## 0.1.3

- Docs: refreshed the README listing with a hero image, screenshot gallery,
  and badges (consistent across the package family). No code changes.

## 0.1.2

- Declares supported `platforms:` (all 6) for the pub.dev listing.

## 0.1.1

- `callTool` throws `McpToolException` when a tool returns `isError: true` (so
  the failure reaches the model) and prefers the server's structured content.

## 0.1.0

Initial release.

- `McpConnection` / `McpToolInfo` — a transport-agnostic contract for listing
  and calling MCP server tools.
- `StreamableHttpMcpConnection.connect(...)` — connects to an MCP server over
  Streamable HTTP (the right transport for mobile/web), backed by `mcp_client`.
- `mcpToolSpecs(connection)` — adapts discovered MCP tools into flutter_ai
  `ToolSpec`s so they register in a `ToolRegistry` and flow through the agent
  loop alongside native tools.

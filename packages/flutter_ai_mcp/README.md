# flutter_ai_mcp

## ☕ Support this project

<p align="center">
  <a href="https://ko-fi.com/ananmouaz"><img src="https://storage.ko-fi.com/cdn/kofi3.png?v=6" alt="Buy me a coffee on Ko-fi" height="72"></a>
</p>

<p align="center"><b>If <code>flutter_ai</code> saves you time, <a href="https://ko-fi.com/ananmouaz">buy me a coffee ☕</a> — it keeps the whole family maintained.</b></p>

---

[Model Context Protocol](https://modelcontextprotocol.io) integration for the
[`flutter_ai`](../../README.md) family. Connect to MCP servers over **Streamable
HTTP** and expose their tools as flutter_ai tools that flow through the agent
loop — no glue code.

## Usage

```dart
import 'package:flutter_ai_mcp/flutter_ai_mcp.dart';
import 'package:flutter_ai_tools/flutter_ai_tools.dart';

// 1. Connect to an MCP server.
final mcp = await StreamableHttpMcpConnection.connect(
  baseUrl: 'https://my-mcp-server.example.com',
  headers: {'Authorization': 'Bearer <token>'},
);

// 2. Adapt its tools into flutter_ai tools.
final registry = ToolRegistry();
for (final spec in await mcpToolSpecs(mcp)) {
  registry.register(spec);
}

// 3. Advertise + run them through the agent loop.
final controller = UseChatController(
  provider: provider,
  tools: registry.definitions,
  onToolCalls: (calls) => Future.wait(calls.map(registry.run)),
);
```

## Scope

- **Streamable HTTP only.** stdio is desktop-only (subprocess) and out of scope
  for a mobile-first toolkit.
- Bring your own transport by implementing `McpConnection` if you prefer a
  different MCP client; `mcpToolSpecs` works with any implementation.

## Status

`0.1.0`. Built on [`mcp_client`](https://pub.dev/packages/mcp_client).

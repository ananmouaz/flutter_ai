<h1 align="center">flutter_ai_mcp</h1>

<p align="center"><b>Model Context Protocol for flutter_ai</b> — connect to MCP servers over Streamable HTTP and expose their tools to the agent loop with no glue code.</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/ananmouaz/flutter_ai/main/docs/media/hero-streaming.png" width="300" alt="MCP tools flowing through the flutter_ai agent loop"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_ai_mcp"><img src="https://img.shields.io/pub/v/flutter_ai_mcp.svg" alt="flutter_ai_mcp on pub.dev"/></a>
  <a href="https://pub.dev/packages/flutter_ai_mcp"><img src="https://img.shields.io/pub/points/flutter_ai_mcp.svg" alt="pub points"/></a>
  <a href="../../LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="License: BSD-3-Clause"/></a>
</p>

<p align="center">
  <b>Family:</b> <a href="../../README.md">flutter_ai</a> ·
  <a href="../flutter_ai_core">core</a> · <a href="../flutter_ai_client">client</a> · <a href="../flutter_ai_elements">elements</a> ·
  <a href="../flutter_ai_tools">tools</a> · <a href="../flutter_ai_voice">voice</a><br/>
  <a href="../../docs/recipes.md">Recipes</a> · <a href="../../docs/migration-from-vercel-ai-sdk.md">Migrating from the Vercel AI SDK</a>
</p>

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
  onToolCalls: (calls, signal) => Future.wait(calls.map(registry.run)),
);
```

## Scope

- **Streamable HTTP only.** stdio is desktop-only (subprocess) and out of scope
  for a mobile-first toolkit.
- Bring your own transport by implementing `McpConnection` if you prefer a
  different MCP client; `mcpToolSpecs` works with any implementation.

## Status

Published on pub.dev (see the CHANGELOG). Built on
[`mcp_client`](https://pub.dev/packages/mcp_client).

## ☕ Support this project

<p align="center">
  <a href="https://ko-fi.com/ananmouaz"><img src="https://storage.ko-fi.com/cdn/kofi3.png?v=6" alt="Buy me a coffee on Ko-fi" height="72"></a>
</p>

<p align="center"><b>If <code>flutter_ai</code> saves you time, <a href="https://ko-fi.com/ananmouaz">buy me a coffee ☕</a> — it keeps the whole family maintained.</b></p>

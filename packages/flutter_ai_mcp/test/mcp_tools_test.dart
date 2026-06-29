import 'package:flutter_ai_mcp/flutter_ai_mcp.dart';
import 'package:test/test.dart';

/// A fake MCP connection that records calls and returns canned data.
class _FakeMcpConnection implements McpConnection {
  _FakeMcpConnection(this._tools);
  final List<McpToolInfo> _tools;
  final List<(String, Map<String, Object?>)> calls = [];
  bool closed = false;

  @override
  Future<List<McpToolInfo>> listTools() async => _tools;

  @override
  Future<Object?> callTool(String name, Map<String, Object?> arguments) async {
    calls.add((name, arguments));
    return '{"ok":true}';
  }

  @override
  Future<void> close() async => closed = true;
}

void main() {
  test('mcpToolSpecs maps discovered tools and wires execution', () async {
    final connection = _FakeMcpConnection(const [
      McpToolInfo(
        name: 'get_weather',
        description: 'Look up weather',
        inputSchema: {
          'type': 'object',
          'properties': {
            'city': {'type': 'string'},
          },
        },
      ),
    ]);

    final specs = await mcpToolSpecs(connection);

    expect(specs, hasLength(1));
    final spec = specs.single;
    expect(spec.name, 'get_weather');
    expect(spec.description, 'Look up weather');
    expect(spec.parametersSchema['type'], 'object');
    expect(spec.toDefinition().name, 'get_weather');

    // The executor calls back into the MCP connection.
    final result = await spec.execute!({'city': 'Lisbon'});
    expect(result, '{"ok":true}');
    expect(connection.calls.single.$1, 'get_weather');
    expect(connection.calls.single.$2, {'city': 'Lisbon'});
  });
}

import 'package:flutter_ai_tools/flutter_ai_tools.dart';
import 'package:test/test.dart';

class _FakeSearch implements WebSearchAdapter {
  String? lastQuery;
  int? lastMax;

  @override
  Future<List<SearchResult>> search(String query, {int? maxResults}) async {
    lastQuery = query;
    lastMax = maxResults;
    return [
      SearchResult(
        title: 'Flutter',
        url: Uri.parse('https://flutter.dev'),
        snippet: 'UI toolkit',
      ),
    ];
  }
}

void main() {
  group('ToolSpec', () {
    test('toDefinition drops the executor', () {
      final spec = ToolSpec(
        name: 'noop',
        description: 'does nothing',
        parametersSchema: const {'type': 'object'},
        execute: (args) => null,
      );
      final def = spec.toDefinition();
      expect(def.name, 'noop');
      expect(def.description, 'does nothing');
      expect(def.parametersSchema, {'type': 'object'});
    });
  });

  group('ToolRegistry', () {
    test('definitions lists all registered tools', () {
      final registry = ToolRegistry([
        const ToolSpec(name: 'a', description: 'A'),
        const ToolSpec(name: 'b', description: 'B'),
      ]);
      expect(registry.definitions.map((d) => d.name), ['a', 'b']);
      expect(registry.isEmpty, isFalse);
    });

    test('register replaces a tool with the same name and [] looks it up', () {
      final registry = ToolRegistry([
        const ToolSpec(name: 'a', description: 'first'),
      ])
        ..register(const ToolSpec(name: 'a', description: 'second'));
      expect(registry['a']?.description, 'second');
      expect(registry['missing'], isNull);
      expect(registry.definitions, hasLength(1));
    });

    test('an empty registry reports isEmpty', () {
      expect(ToolRegistry().isEmpty, isTrue);
    });

    test('run executes the matching tool', () async {
      final registry = ToolRegistry([
        ToolSpec(
          name: 'add',
          description: 'add',
          execute: (args) => (args['a']! as int) + (args['b']! as int),
        ),
      ]);
      final result = await registry.run(
        const ToolCallPart(
          toolCallId: 'c1',
          toolName: 'add',
          args: {'a': 2, 'b': 3},
          state: ToolCallState.inputAvailable,
        ),
      );
      expect(result.result, 5);
      expect(result.isError, isFalse);
      expect(result.toolCallId, 'c1');
    });

    test('run returns an error result for an unknown tool', () async {
      final registry = ToolRegistry();
      final result = await registry.run(
        const ToolCallPart(toolCallId: 'c1', toolName: 'ghost'),
      );
      expect(result.isError, isTrue);
    });

    test('run captures a thrown executor as an error result', () async {
      final registry = ToolRegistry([
        ToolSpec(
          name: 'boom',
          description: 'throws',
          execute: (args) => throw StateError('nope'),
        ),
      ]);
      final result = await registry.run(
        const ToolCallPart(toolCallId: 'c1', toolName: 'boom'),
      );
      expect(result.isError, isTrue);
      expect(result.result, contains('nope'));
    });

    test('run reports tools that have no executor', () async {
      final registry = ToolRegistry([
        const ToolSpec(name: 'server_side', description: 'no exec'),
      ]);
      final result = await registry.run(
        const ToolCallPart(toolCallId: 'c1', toolName: 'server_side'),
      );
      expect(result.isError, isTrue);
    });
  });

  group('webSearchTool', () {
    test('forwards the query and maps results', () async {
      final adapter = _FakeSearch();
      final tool = webSearchTool(adapter, maxResults: 3);
      final output =
          await tool.execute!({'query': 'flutter'}) as Map<String, Object?>;

      expect(adapter.lastQuery, 'flutter');
      expect(adapter.lastMax, 3);
      final results = output['results']! as List;
      expect(results, hasLength(1));
      expect((results.first as Map)['url'], 'https://flutter.dev');
    });

    test('short-circuits an empty query', () async {
      final adapter = _FakeSearch();
      final tool = webSearchTool(adapter);
      final output =
          await tool.execute!({'query': '  '}) as Map<String, Object?>;
      expect(output['results'], isEmpty);
      expect(adapter.lastQuery, isNull);
    });
  });

  group('SearchResult', () {
    test('round-trips through JSON', () {
      final result = SearchResult(
        title: 'T',
        url: Uri.parse('https://x.test'),
        snippet: 's',
      );
      expect(SearchResult.fromJson(result.toJson()), result);
    });
  });
}

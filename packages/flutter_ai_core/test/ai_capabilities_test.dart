import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:test/test.dart';

/// A fake provider that replays a fixed list of [AiStreamEvent]s, so the
/// structured-output helpers can be exercised without any network.
class _FakeProvider implements LlmProvider {
  _FakeProvider(this.events);

  final List<AiStreamEvent> events;
  AiRequestOptions? lastOptions;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    lastOptions = options;
    for (final event in events) {
      yield event;
    }
  }
}

/// Splits [text] into individual character TextDeltas, simulating streaming.
List<AiStreamEvent> _streamText(String text, {String id = 'm1'}) => [
      MessageStarted(messageId: id, role: AiRole.assistant),
      for (final char in text.split('')) TextDelta(messageId: id, delta: char),
      const MessageFinished(messageId: 'm1', reason: FinishReason.stop),
    ];

void main() {
  group('AiEmbedding', () {
    test('value equality over values and index', () {
      expect(
        const AiEmbedding([1, 2, 3], index: 0),
        const AiEmbedding([1, 2, 3], index: 0),
      );
      expect(
        const AiEmbedding([1, 2, 3], index: 0).hashCode,
        const AiEmbedding([1, 2, 3], index: 0).hashCode,
      );
      expect(
        const AiEmbedding([1, 2, 3], index: 0),
        isNot(const AiEmbedding([1, 2, 4], index: 0)),
      );
      expect(
        const AiEmbedding([1, 2, 3], index: 0),
        isNot(const AiEmbedding([1, 2, 3], index: 1)),
      );
    });

    test('toString reports dimensions and index', () {
      expect(
        const AiEmbedding([1, 2, 3], index: 2).toString(),
        'AiEmbedding(3 dims, index: 2)',
      );
    });
  });

  group('generateObject', () {
    const format = AiResponseFormat(
      schema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'age': {'type': 'integer'},
        },
      },
    );

    test('decodes the streamed JSON text into a Map', () async {
      final provider = _FakeProvider(_streamText('{"name":"Ada","age":36}'));

      final object = await provider.generateObject(
        const AiConversation.empty('c'),
        format: format,
      );

      expect(object, {'name': 'Ada', 'age': 36});
    });

    test('sets responseFormat on the merged options', () async {
      final provider = _FakeProvider(_streamText('{}'));

      await provider.generateObject(
        const AiConversation.empty('c'),
        format: format,
        options: const AiRequestOptions(model: 'gpt-test', temperature: 0.2),
      );

      expect(provider.lastOptions?.responseFormat, format);
      // Pre-existing fields are preserved when merging.
      expect(provider.lastOptions?.model, 'gpt-test');
      expect(provider.lastOptions?.temperature, 0.2);
    });

    test('throws FormatException with the raw text on a parse failure',
        () async {
      final provider = _FakeProvider(_streamText('not json'));

      await expectLater(
        provider.generateObject(
          const AiConversation.empty('c'),
          format: format,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.source,
            'source',
            'not json',
          ),
        ),
      );
    });
  });

  group('streamObject', () {
    const format = AiResponseFormat(schema: {'type': 'object'});

    test('yields growing prefixes ending in the complete object', () async {
      final provider = _FakeProvider(_streamText('{"a":1,"b":2}'));

      final frames = await provider
          .streamObject(const AiConversation.empty('c'), format: format)
          .toList();

      // The final frame is the complete object.
      expect(frames.last, {'a': 1, 'b': 2});
      // Every frame is a (growing) prefix: each is a submap of the next.
      for (var i = 0; i < frames.length - 1; i++) {
        for (final entry in frames[i].entries) {
          expect(frames[i + 1][entry.key], entry.value);
        }
        expect(frames[i].length, lessThanOrEqualTo(frames[i + 1].length));
      }
    });
  });
}

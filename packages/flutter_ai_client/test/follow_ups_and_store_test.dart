import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// A provider that replays fixed events, recording the conversation it saw.
class ScriptedProvider implements LlmProvider {
  ScriptedProvider(this.events);

  final List<AiStreamEvent> events;
  AiConversation? lastConversation;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    lastConversation = conversation;
    for (final event in events) {
      yield event;
    }
  }
}

/// An in-memory [KeyValueStore] standing in for shared_preferences/a file.
class MapKeyValueStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);
}

AiConversation _conv(String id, List<String> userTexts) => AiConversation(
      id: id,
      messages: [
        for (var i = 0; i < userTexts.length; i++)
          AiMessage.text(id: 'm$i', role: AiRole.user, text: userTexts[i]),
      ],
    );

void main() {
  group('suggestFollowUps', () {
    test('parses one-per-line, strips markers, and caps at count', () async {
      final provider = ScriptedProvider([
        const MessageStarted(messageId: 'a1', role: AiRole.assistant),
        const TextDelta(messageId: 'a1', delta: '1. What about pricing?\n'),
        const TextDelta(messageId: 'a1', delta: '- How do I deploy?\n'),
        const TextDelta(messageId: 'a1', delta: '"Any alternatives?"\n'),
        const TextDelta(messageId: 'a1', delta: 'Extra one that is dropped\n'),
        const MessageFinished(messageId: 'a1', reason: FinishReason.stop),
      ]);

      final result = await suggestFollowUps(
        _conv('c1', ['Tell me about the product']),
        provider,
        count: 3,
      );

      expect(result,
          ['What about pricing?', 'How do I deploy?', 'Any alternatives?']);
      // The follow-up instruction is appended to the sent conversation.
      expect(provider.lastConversation!.messages.length, 2);
    });

    test('returns empty for an empty conversation without calling send',
        () async {
      final provider = ScriptedProvider([]);
      final result =
          await suggestFollowUps(const AiConversation.empty('c0'), provider);
      expect(result, isEmpty);
      expect(provider.lastConversation, isNull);
    });
  });

  group('KeyValueChatThreadStore', () {
    test('round-trips conversations and maintains a newest-first index',
        () async {
      final kv = MapKeyValueStore();
      final store = KeyValueChatThreadStore(kv);

      await store.save('t1', _conv('t1', ['First thread hello']));
      await store.save('t2', _conv('t2', ['Second thread hi']));

      final loaded = await store.load('t1');
      expect(loaded, isNotNull);
      expect(loaded!.messages.single.text, 'First thread hello');

      final threads = await store.listThreads();
      expect(threads.map((t) => t.id), ['t2', 't1']); // newest first
      expect(threads.first.title, 'Second thread hi');

      await store.delete('t1');
      expect(await store.load('t1'), isNull);
      expect((await store.listThreads()).map((t) => t.id), ['t2']);
    });

    test('survives a fresh store instance over the same backing storage',
        () async {
      final kv = MapKeyValueStore();
      await KeyValueChatThreadStore(kv).save('t1', _conv('t1', ['persisted']));

      // A new app launch: a new store over the same storage.
      final reopened = KeyValueChatThreadStore(kv);
      expect((await reopened.load('t1'))!.messages.single.text, 'persisted');
      expect((await reopened.listThreads()).single.id, 't1');
    });
  });

  group('UseChatController.load', () {
    void syncScheduler(void Function() callback) => callback();

    test('swaps the transcript in place and resets branch state', () {
      final controller = UseChatController(
        provider: ScriptedProvider([]),
        initial: _conv('a', ['old thread']),
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      controller.load(_conv('b', ['new thread', 'and more']));

      expect(controller.conversation.id, 'b');
      expect(controller.messages.length, 2);
      expect(controller.messages.first.text, 'new thread');
      expect(controller.status, ChatStatus.idle);
      expect(controller.branchCount, 0);
    });
  });
}

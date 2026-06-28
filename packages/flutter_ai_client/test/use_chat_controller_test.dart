import 'dart:async';

import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// A provider whose stream is driven manually by the test.
class ManualProvider implements LlmProvider {
  StreamController<AiStreamEvent>? _controller;

  /// The controller backing the most recent [send] call.
  StreamController<AiStreamEvent> get current => _controller!;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) {
    // ignore: close_sinks — test fixture; closed indirectly via controller.stop.
    final controller = StreamController<AiStreamEvent>();
    _controller = controller;
    return controller.stream;
  }
}

/// A provider that replays a fixed list of events, then closes.
class ScriptedProvider implements LlmProvider {
  ScriptedProvider(this.events);

  final List<AiStreamEvent> events;
  int sendCount = 0;
  AiConversation? lastConversation;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    sendCount++;
    lastConversation = conversation;
    for (final event in events) {
      yield event;
    }
  }
}

void main() {
  // Run scheduled notifications synchronously for deterministic assertions.
  void syncScheduler(void Function() callback) => callback();

  group('sendText / submit', () {
    test('appends the user message optimistically before any response', () {
      final provider = ManualProvider();
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
        idGenerator: () => 'u1',
      );
      addTearDown(controller.dispose);

      unawaited(controller.sendText('Hello'));

      expect(controller.messages, hasLength(1));
      expect(controller.messages.single.role, AiRole.user);
      expect(controller.messages.single.text, 'Hello');
      expect(controller.status, ChatStatus.submitted);
    });

    test('folds streamed events into an assistant message', () async {
      final provider = ScriptedProvider(const [
        MessageStarted(messageId: 'a1', role: AiRole.assistant),
        TextDelta(messageId: 'a1', delta: 'Hi '),
        TextDelta(messageId: 'a1', delta: 'there'),
        MessageFinished(messageId: 'a1', reason: FinishReason.stop),
      ]);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
        idGenerator: () => 'u1',
      );
      addTearDown(controller.dispose);

      await controller.sendText('Hello');

      expect(controller.status, ChatStatus.idle);
      expect(controller.messages.map((m) => m.role), [
        AiRole.user,
        AiRole.assistant,
      ]);
      expect(controller.messages.last.text, 'Hi there');
      expect(controller.messages.last.status, AiMessageStatus.complete);
    });

    test('sendText with empty text and no attachments is a no-op', () async {
      final provider = ScriptedProvider(const []);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      await controller.sendText('');
      expect(controller.messages, isEmpty);
      expect(provider.sendCount, 0);
    });

    test('notifies listeners as the turn progresses', () async {
      final provider = ScriptedProvider(const [
        TextDelta(messageId: 'a1', delta: 'x'),
        MessageFinished(messageId: 'a1', reason: FinishReason.stop),
      ]);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.sendText('hi');
      expect(notifications, greaterThan(0));
    });
  });

  group('events stream', () {
    test('re-emits applied events', () async {
      final provider = ScriptedProvider(const [
        TextDelta(messageId: 'a1', delta: 'one'),
        MessageFinished(messageId: 'a1', reason: FinishReason.stop),
      ]);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      final seen = <AiStreamEvent>[];
      final sub = controller.events.listen(seen.add);
      addTearDown(sub.cancel);

      await controller.sendText('hi');
      expect(seen, hasLength(2));
      expect(seen.first, isA<TextDelta>());
    });
  });

  group('stop', () {
    test('cancels streaming and finalizes the message as stopped', () async {
      final provider = ManualProvider();
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
        idGenerator: () => 'u1',
      );
      addTearDown(controller.dispose);

      final turn = controller.sendText('Hello');
      provider.current.add(
        const MessageStarted(messageId: 'a1', role: AiRole.assistant),
      );
      provider.current.add(const TextDelta(messageId: 'a1', delta: 'partial'));
      await Future<void>.delayed(Duration.zero);

      controller.stop();
      await turn; // stop completes the in-flight turn future

      expect(controller.status, ChatStatus.idle);
      final assistant = controller.messages.last;
      expect(assistant.status, AiMessageStatus.complete);
      expect(assistant.finishReason, FinishReason.stop);
    });
  });

  group('regenerate', () {
    test('drops the prior assistant turn and re-runs from the user message',
        () async {
      final provider = ScriptedProvider(const [
        MessageStarted(messageId: 'a1', role: AiRole.assistant),
        TextDelta(messageId: 'a1', delta: 'answer'),
        MessageFinished(messageId: 'a1', reason: FinishReason.stop),
      ]);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
        idGenerator: () => 'u1',
      );
      addTearDown(controller.dispose);

      await controller.sendText('question');
      expect(controller.messages, hasLength(2));

      await controller.regenerate();
      expect(provider.sendCount, 2);
      // Still exactly one user + one assistant; the old assistant was dropped.
      expect(controller.messages.map((m) => m.role), [
        AiRole.user,
        AiRole.assistant,
      ]);
    });

    test('is a no-op with no user message', () async {
      final provider = ScriptedProvider(const []);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      await controller.regenerate();
      expect(provider.sendCount, 0);
    });
  });

  group('error handling', () {
    test('surfaces a thrown provider error as error status', () async {
      final provider = _ThrowingProvider();
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      await controller.sendText('hi');
      expect(controller.status, ChatStatus.error);
      expect(controller.error, isNotNull);
    });

    test('surfaces an in-band StreamErrorEvent as error status', () async {
      final provider = ScriptedProvider(const [
        MessageStarted(messageId: 'a1', role: AiRole.assistant),
        StreamErrorEvent(error: 'upstream timeout', messageId: 'a1'),
      ]);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      await controller.sendText('hi');
      expect(controller.status, ChatStatus.error);
      expect(controller.error, 'upstream timeout');
    });
  });

  group('addToolResults', () {
    test('appends a tool message and continues the turn', () async {
      final provider = ScriptedProvider(const [
        MessageStarted(messageId: 'a2', role: AiRole.assistant),
        TextDelta(messageId: 'a2', delta: 'done'),
        MessageFinished(messageId: 'a2', reason: FinishReason.stop),
      ]);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
        idGenerator: () => 't1',
      );
      addTearDown(controller.dispose);

      await controller.addToolResults(const [
        ToolResultPart(toolCallId: 'c1', result: 'ok'),
      ]);

      expect(provider.sendCount, 1);
      expect(controller.messages.first.role, AiRole.tool);
      expect(controller.messages.last.role, AiRole.assistant);
      expect(controller.messages.last.text, 'done');
    });

    test('is a no-op with empty results', () async {
      final provider = ScriptedProvider(const []);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      await controller.addToolResults(const []);
      expect(provider.sendCount, 0);
      expect(controller.messages, isEmpty);
    });
  });

  group('configuration', () {
    test('setOptions forwards new options to the provider', () async {
      final provider = _OptionsCapturingProvider();
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      controller.setOptions(const AiRequestOptions(model: 'gpt-4o-mini'));
      await controller.sendText('hi');
      expect(provider.lastOptions?.model, 'gpt-4o-mini');
    });

    test('setTools forwards new tools to the provider', () async {
      final provider = _ToolsCapturingProvider();
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      controller.setTools(const [
        ToolDefinition(name: 'lookup', description: 'Looks something up'),
      ]);
      await controller.sendText('hi');
      expect(provider.lastTools, hasLength(1));
      expect(provider.lastTools?.single.name, 'lookup');
    });

    test('clear empties the transcript', () async {
      final provider = ScriptedProvider(const [
        MessageFinished(messageId: 'a1', reason: FinishReason.stop),
      ]);
      final controller = UseChatController(
        provider: provider,
        scheduler: syncScheduler,
      );
      addTearDown(controller.dispose);

      await controller.sendText('hi');
      expect(controller.messages, isNotEmpty);
      controller.clear();
      expect(controller.messages, isEmpty);
      expect(controller.status, ChatStatus.idle);
    });
  });
}

class _ThrowingProvider implements LlmProvider {
  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    throw StateError('provider exploded');
  }
}

class _OptionsCapturingProvider implements LlmProvider {
  AiRequestOptions? lastOptions;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    lastOptions = options;
    yield const MessageFinished(messageId: 'a1', reason: FinishReason.stop);
  }
}

class _ToolsCapturingProvider implements LlmProvider {
  List<ToolDefinition>? lastTools;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    lastTools = tools;
    yield const MessageFinished(messageId: 'a1', reason: FinishReason.stop);
  }
}

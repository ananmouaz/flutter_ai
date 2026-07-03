import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Echoes a fixed assistant reply.
class _EchoProvider implements LlmProvider {
  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    yield const MessageStarted(messageId: 'a1', role: AiRole.assistant);
    yield const TextDelta(messageId: 'a1', delta: 'Echo reply');
    yield const MessageFinished(messageId: 'a1', reason: FinishReason.stop);
  }
}

/// A test double for [AiVoiceEngine] whose turns are advanced by the test.
class _FakeEngine implements AiVoiceEngine {
  int listenCalls = 0;
  int speakCalls = 0;
  String? lastSpoken;
  void Function(String finalText)? _onListenDone;
  void Function()? _onSpeakDone;

  void finishListening(String text) => _onListenDone?.call(text);
  void finishSpeaking() => _onSpeakDone?.call();

  @override
  Future<void> startListening({
    required void Function(String text) onPartial,
    required void Function(String finalText) onDone,
    void Function(double level)? onLevel,
  }) async {
    listenCalls++;
    _onListenDone = onDone;
  }

  @override
  Future<void> speak(String text, {required void Function() onDone}) async {
    speakCalls++;
    lastSpoken = text;
    _onSpeakDone = onDone;
  }

  @override
  Future<void> stopListening() async {}
  @override
  Future<void> stopSpeaking() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  group('AiMessageActions ordering', () {
    const message = AiMessage(
      id: 'a1',
      role: AiRole.assistant,
      parts: [TextPart('hi')],
    );

    testWidgets('no trailing → compact row, no spacer', (tester) async {
      await tester.pumpWidget(_wrap(
        AiMessageActions(message: message, onSpeak: () {}, onRegenerate: () {}),
      ));
      expect(find.byType(Spacer), findsNothing);
    });

    testWidgets('trailing set pushes an action to the far side via a spacer',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AiMessageActions(
          message: message,
          onSpeak: () {},
          onGood: () {},
          trailing: const {AiMessageActionKind.speak},
        ),
      ));
      expect(find.byType(Spacer), findsOneWidget);
    });
  });

  group('AiModelSelector theming', () {
    testWidgets('labelBuilder replaces the trigger label', (tester) async {
      await tester.pumpWidget(_wrap(
        AiModelSelector(
          models: const [AiModelOption(id: 'pro', label: 'Pro')],
          selectedId: 'pro',
          onSelected: (_) {},
          showBorder: false,
          labelBuilder: (context, selected) => Text('Gemini ${selected.label}'),
        ),
      ));
      expect(find.text('Gemini Pro'), findsOneWidget);
    });
  });

  group('AiLiveController', () {
    test('runs listen → send → speak → re-listen', () async {
      final controller = UseChatController(
        provider: _EchoProvider(),
        scheduler: (cb) => cb(),
      );
      addTearDown(controller.dispose);
      final engine = _FakeEngine();
      final live = AiLiveController(controller: controller, engine: engine);
      addTearDown(live.dispose);

      live.start();
      expect(engine.listenCalls, 1);
      expect(live.status, AiLiveStatus.listening);

      // User finishes speaking → controller sends → assistant echoes.
      engine.finishListening('hello there');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.messages.first.text, 'hello there');
      expect(live.status, AiLiveStatus.speaking);
      expect(engine.speakCalls, 1);
      expect(engine.lastSpoken, 'Echo reply');

      // TTS finishes → back to listening.
      engine.finishSpeaking();
      expect(live.status, AiLiveStatus.listening);
      expect(engine.listenCalls, 2);

      live.stop();
      expect(live.status, AiLiveStatus.ended);
    });

    test('empty transcript re-listens without sending', () async {
      final controller = UseChatController(
        provider: _EchoProvider(),
        scheduler: (cb) => cb(),
      );
      addTearDown(controller.dispose);
      final engine = _FakeEngine();
      final live = AiLiveController(controller: controller, engine: engine);
      addTearDown(live.dispose);

      live.start();
      engine.finishListening('   ');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.messages, isEmpty);
      expect(engine.speakCalls, 0);
      expect(engine.listenCalls, 2); // listened again
    });
  });
}

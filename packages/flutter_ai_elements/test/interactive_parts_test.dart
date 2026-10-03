import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

const _message = AiMessage(id: 'answer', role: AiRole.assistant, parts: [
  ToolResultPart(toolCallId: 'hidden', result: null),
  DataPart(dataType: 'question', data: {}),
  DataPart(dataType: 'unknown', data: {}),
]);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

class _Provider implements LlmProvider {
  @override
  Stream<AiStreamEvent> send(AiConversation conversation,
          {List<ToolDefinition>? tools, AiRequestOptions? options}) =>
      const Stream.empty();
}

void main() {
  for (final wrapper in ['bubble', 'conversation', 'chat', 'chatView']) {
    testWidgets(
        '$wrapper forwards registry and addressed action, preserving JSON',
        (tester) async {
      const initial = AiConversation(id: 'thread', messages: [_message]);
      final before = jsonEncode(initial.toJson());
      final controller =
          UseChatController(provider: _Provider(), initial: initial);
      addTearDown(controller.dispose);
      final received = <(AiPartRef, Object?)>[];
      void action(AiPartRef ref, Object? value) => received.add((ref, value));
      final registry = AiWidgetRegistry()
        ..register('question', (context, _) {
          final scope = AiPartScope.maybeOf(context)!;
          return AiConfirmation(
              title: 'Approve?',
              onConfirm:
                  scope.onAction == null ? null : () => scope.onAction!(true));
        });
      Widget? builder(BuildContext context, AiPart part, AiMessage message) =>
          part is DataPart && part.dataType == 'unknown'
              ? const Text('custom unknown')
              : null;
      final view = switch (wrapper) {
        'bubble' => AiMessageBubble(
            message: _message,
            widgetRegistry: registry,
            onPartAction: action,
            partBuilder: builder),
        'conversation' => AiConversationView(
            messages: const [_message],
            widgetRegistry: registry,
            onPartAction: action,
            partBuilder: builder),
        'chat' => AiChat(
            controller: controller,
            widgetRegistry: registry,
            onPartAction: action,
            partBuilder: builder),
        _ => AiChatView(
            controller: controller,
            widgetRegistry: registry,
            onPartAction: action,
            partBuilder: builder),
      };
      await tester.pumpWidget(_wrap(view));
      await tester.tap(find.text('Allow'));
      expect(received,
          [(const AiPartRef(messageId: 'answer', partIndex: 1), true)]);
      expect(jsonEncode(controller.conversation.toJson()), before);
      expect(find.text('custom unknown'), findsOneWidget);
    });
  }

  testWidgets('part builder precedes registry and inherits bubble text style',
      (tester) async {
    Color? inheritedColor;
    AiPartRef? ref;
    final theme =
        AiThemeExtension.fallback().copyWith(assistantTextColor: Colors.purple);
    final registry = AiWidgetRegistry()
      ..register('question', (_, __) => const Text('registry'));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [theme]),
      home: Scaffold(
          body: AiConversationView(
        messages: const [_message],
        widgetRegistry: registry,
        partBuilder: (context, part, message) {
          if (part is! DataPart || part.dataType != 'question') return null;
          inheritedColor = DefaultTextStyle.of(context).style.color;
          ref = AiPartScope.maybeOf(context)!.ref;
          return const Text('override');
        },
      )),
    ));
    expect(find.text('override'), findsOneWidget);
    expect(find.text('registry'), findsNothing);
    expect(find.text('unknown'), findsOneWidget);
    expect(inheritedColor, Colors.purple);
    expect(ref, const AiPartRef(messageId: 'answer', partIndex: 1));
  });

  testWidgets(
      'custom registry and captured state refresh with identical messages',
      (tester) async {
    var label = 'first';
    final registry = AiWidgetRegistry()
      ..register('question', (_, __) => Text(label));
    Widget view() => _wrap(AiConversationView(
        messages: const [_message], widgetRegistry: registry));
    await tester.pumpWidget(view());
    expect(find.text('first'), findsOneWidget);
    label = 'second';
    await tester.pumpWidget(view());
    expect(find.text('second'), findsOneWidget);
    registry.register('question', (_, __) => const Text('replacement'));
    await tester.pumpWidget(view());
    expect(find.text('replacement'), findsOneWidget);
    await tester
        .pumpWidget(_wrap(const AiConversationView(messages: [_message])));
    expect(find.text('question'), findsOneWidget);
  });

  testWidgets('missing handler and streaming messages expose inert actions',
      (tester) async {
    final actions = <Object?>[];
    final registry = AiWidgetRegistry()
      ..register(
          'question',
          (context, _) => AiQuestion(
              prompt: 'Choose',
              allowFreeform: true,
              onSubmit: AiPartScope.maybeOf(context)!.onAction));
    await tester.pumpWidget(
        _wrap(AiMessageBubble(message: _message, widgetRegistry: registry)));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    await tester.pumpWidget(_wrap(AiMessageBubble(
        message: _message.copyWith(status: AiMessageStatus.streaming),
        widgetRegistry: registry,
        onPartAction: (_, value) => actions.add(value))));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    expect(actions, isEmpty);
  });

  testWidgets('question answer restored after transcript eviction is inert',
      (tester) async {
    AiQuestionResponse? answer;
    var submissions = 0;
    final registry = AiWidgetRegistry()
      ..register(
          'question',
          (context, _) => AiQuestion(
              prompt: 'Your name?',
              allowFreeform: true,
              answer: answer,
              onSubmit: AiPartScope.maybeOf(context)!.onAction));
    Widget view() => _wrap(AiConversationView(
        messages: const [_message],
        widgetRegistry: registry,
        onPartAction: (_, value) {
          submissions++;
          answer = value! as AiQuestionResponse;
        }));
    await tester.pumpWidget(view());
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_wrap(const SizedBox()));
    await tester.pumpWidget(view());
    expect(find.text('Answered: Ada'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(submissions, 1);
  });
}

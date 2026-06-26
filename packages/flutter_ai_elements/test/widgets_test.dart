import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

class _EchoProvider implements LlmProvider {
  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    yield const MessageStarted(messageId: 'a1', role: AiRole.assistant);
    yield const TextDelta(messageId: 'a1', delta: 'Echo');
    yield const MessageFinished(messageId: 'a1', reason: FinishReason.stop);
  }
}

void main() {
  group('AiThemeExtension', () {
    test('of returns the fallback when none is registered', () {
      final fallback = AiThemeExtension.fallback();
      expect(fallback.enableHaptics, isTrue);
      expect(fallback.maxBubbleWidthFraction, closeTo(0.82, 0.001));
    });

    test('copyWith overrides only the given token', () {
      final base = AiThemeExtension.fallback();
      final edited = base.copyWith(enableHaptics: false);
      expect(edited.enableHaptics, isFalse);
      expect(edited.userBubbleColor, base.userBubbleColor);
    });

    test('lerp interpolates continuous tokens and snaps discrete ones', () {
      final a = AiThemeExtension.fallback();
      final b = a.copyWith(messageSpacing: 30, enableHaptics: false);
      final lerped = a.lerp(b, 0.4);
      expect(lerped.messageSpacing, closeTo(18, 0.001)); // 10 + 0.4 * 20
      expect(lerped.enableHaptics, isTrue); // snaps to `a` while t < 0.5
    });
  });

  group('AiMessageBubble', () {
    testWidgets('renders text and right-aligns the user', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiMessageBubble(
            message: AiMessage(
              id: 'm1',
              role: AiRole.user,
              parts: [TextPart('Hello there')],
            ),
          ),
        ),
      );
      expect(find.text('Hello there'), findsOneWidget);
      final align = tester.widget<Align>(find.byType(Align).first);
      expect(align.alignment, Alignment.centerRight);
    });

    testWidgets('excludes semantics while streaming', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiMessageBubble(
            message: AiMessage(
              id: 'm1',
              role: AiRole.assistant,
              parts: [TextPart('partial')],
              status: AiMessageStatus.streaming,
            ),
          ),
        ),
      );
      expect(find.byType(ExcludeSemantics), findsAtLeastNWidgets(1));
    });

    testWidgets('renders a tool call line', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiMessageBubble(
            message: AiMessage(
              id: 'm1',
              role: AiRole.assistant,
              parts: [
                ToolCallPart(
                  toolCallId: 'c1',
                  toolName: 'get_weather',
                  state: ToolCallState.outputAvailable,
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.textContaining('get_weather'), findsOneWidget);
    });
  });

  group('AiComposer', () {
    testWidgets('sends trimmed text and clears the field', (tester) async {
      String? sent;
      await tester.pumpWidget(
        _wrap(AiComposer(onSend: (t) => sent = t)),
      );
      await tester.enterText(find.byType(TextField), '  hi  ');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      expect(sent, 'hi');
      expect(find.text('  hi  '), findsNothing);
    });

    testWidgets('shows Stop while busy and calls onStop', (tester) async {
      var stopped = false;
      await tester.pumpWidget(
        _wrap(
          AiComposer(
            onSend: (_) {},
            onStop: () => stopped = true,
            isBusy: true,
          ),
        ),
      );
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.stop_rounded));
      expect(stopped, isTrue);
    });
  });

  group('AiChat (controller-bound)', () {
    testWidgets('renders the streamed conversation', (tester) async {
      final controller = UseChatController(provider: _EchoProvider());
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(AiChat(controller: controller)));
      await controller.sendText('hi');
      await tester.pumpAndSettle();

      expect(find.text('hi'), findsOneWidget);
      expect(find.text('Echo'), findsOneWidget);
    });
  });

  group('AiToolInvocation', () {
    const call = ToolCallPart(
      toolCallId: 'c1',
      toolName: 'get_weather',
      args: {'city': 'London'},
      state: ToolCallState.outputAvailable,
    );

    testWidgets('shows the tool name and is collapsed by default',
        (tester) async {
      await tester.pumpWidget(_wrap(const AiToolInvocation(call: call)));
      expect(find.text('get_weather'), findsOneWidget);
      expect(find.text('Arguments'), findsNothing);
    });

    testWidgets('reveals arguments and result when expanded', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiToolInvocation(
            call: call,
            result: ToolResultPart(toolCallId: 'c1', result: {'tempC': 21}),
            initiallyExpanded: true,
          ),
        ),
      );
      expect(find.text('Arguments'), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
      expect(find.textContaining('London'), findsOneWidget);
    });

    testWidgets('expands on tap', (tester) async {
      await tester.pumpWidget(_wrap(const AiToolInvocation(call: call)));
      await tester.tap(find.text('get_weather'));
      await tester.pumpAndSettle();
      expect(find.text('Arguments'), findsOneWidget);
    });
  });

  group('AiReasoning', () {
    testWidgets('hides text until expanded', (tester) async {
      await tester.pumpWidget(
        _wrap(const AiReasoning(text: 'step by step')),
      );
      expect(find.text('Reasoning'), findsOneWidget);
      expect(find.text('step by step'), findsNothing);

      await tester.tap(find.text('Reasoning'));
      await tester.pumpAndSettle();
      expect(find.text('step by step'), findsOneWidget);
    });
  });

  group('AiAttachment', () {
    testWidgets('renders a file chip for non-images', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiAttachment(
            file: FilePart(mediaType: 'application/pdf', name: 'report.pdf'),
          ),
        ),
      );
      expect(find.text('report.pdf'), findsOneWidget);
    });
  });

  group('AiToolGroup', () {
    testWidgets('stacks one card per call', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiToolGroup(
            calls: [
              ToolCallPart(toolCallId: 'c1', toolName: 'alpha'),
              ToolCallPart(toolCallId: 'c2', toolName: 'beta'),
            ],
          ),
        ),
      );
      expect(find.byType(AiToolInvocation), findsNWidgets(2));
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
    });
  });

  group('AiConversationView', () {
    testWidgets('renders a bubble per message plus a loader', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiConversationView(
            showLoader: true,
            messages: [
              AiMessage(id: 'm1', role: AiRole.user, parts: [TextPart('one')]),
              AiMessage(id: 'm2', role: AiRole.user, parts: [TextPart('two')]),
            ],
          ),
        ),
      );
      expect(find.byType(AiMessageBubble), findsNWidgets(2));
      expect(find.byType(AiLoader), findsOneWidget);
    });
  });
}

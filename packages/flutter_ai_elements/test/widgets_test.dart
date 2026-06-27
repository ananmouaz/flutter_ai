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
      expect(fallback.maxBubbleWidthFraction, closeTo(0.80, 0.001));
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
      expect(lerped.messageSpacing, closeTo(22.8, 0.001)); // 18 + 0.4 * 12
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

  group('expanded elements', () {
    testWidgets('AiAvatar shows a role icon', (tester) async {
      await tester.pumpWidget(_wrap(const AiAvatar(role: AiRole.assistant)));
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('AiEmptyState shows title and subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(const AiEmptyState(title: 'Hello', subtitle: 'Ask me anything')),
      );
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Ask me anything'), findsOneWidget);
    });

    testWidgets('AiErrorBanner shows message and fires retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          AiErrorBanner(message: 'boom', onRetry: () => retried = true),
        ),
      );
      expect(find.text('boom'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('AiSuggestions reports the chosen suggestion', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        _wrap(
          AiSuggestions(
            suggestions: const ['Summarize', 'Translate'],
            onSelected: (s) => chosen = s,
          ),
        ),
      );
      await tester.tap(find.text('Translate'));
      expect(chosen, 'Translate');
    });

    testWidgets('AiSources renders a chip per source', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AiSources(
            sources: [
              SourcePart(
                url: Uri.parse('https://flutter.dev'),
                title: 'Flutter',
              ),
              SourcePart(url: Uri.parse('https://dart.dev')),
            ],
          ),
        ),
      );
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('dart.dev'), findsOneWidget); // falls back to host
    });

    testWidgets('AiCodeBlock shows code and a copy button', (tester) async {
      await tester.pumpWidget(
        _wrap(const AiCodeBlock(code: 'print("hi");', language: 'dart')),
      );
      expect(find.text('dart'), findsOneWidget);
      expect(find.text('print("hi");'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('AiMessageActions fires regenerate', (tester) async {
      var regenerated = false;
      await tester.pumpWidget(
        _wrap(
          AiMessageActions(
            message: const AiMessage(
              id: 'm1',
              role: AiRole.assistant,
              parts: [TextPart('hi')],
            ),
            onRegenerate: () => regenerated = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.refresh));
      expect(regenerated, isTrue);
    });

    testWidgets('AiChat shows the empty state when idle and empty',
        (tester) async {
      final controller = UseChatController(provider: _EchoProvider());
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          AiChat(
            controller: controller,
            emptyState: const AiEmptyState(title: 'Nothing yet'),
          ),
        ),
      );
      expect(find.text('Nothing yet'), findsOneWidget);
    });
  });

  group('new components', () {
    testWidgets('AiResponse renders markdown blocks', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SingleChildScrollView(
            child: AiResponse(
              text: '# Title\n\nHello **world** and `code`.\n\n'
                  '```dart\nx();\n```\n\n- one\n- two',
            ),
          ),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.byType(AiCodeBlock), findsOneWidget);
      expect(find.text('one'), findsOneWidget);
    });

    testWidgets('AiChainOfThought reveals steps when expanded',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiChainOfThought(
            initiallyExpanded: true,
            steps: [
              AiThoughtStep(label: 'Search'),
              AiThoughtStep(label: 'Synthesize', isActive: true),
            ],
          ),
        ),
      );
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Synthesize'), findsOneWidget);
    });

    testWidgets('AiTask shows title, count, and items', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiTask(
            title: 'Refactor',
            items: [
              AiTaskItem(label: 'Read files', status: AiTaskStatus.complete),
              AiTaskItem(label: 'Apply edits', status: AiTaskStatus.active),
            ],
          ),
        ),
      );
      expect(find.text('Refactor'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Read files'), findsOneWidget);
    });

    testWidgets('AiInlineCitation shows its number', (tester) async {
      await tester.pumpWidget(_wrap(const AiInlineCitation(number: 3)));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('AiBranch shows position and hides when single', (tester) async {
      await tester.pumpWidget(_wrap(const AiBranch(index: 1, total: 3)));
      expect(find.text('2/3'), findsOneWidget);

      await tester.pumpWidget(_wrap(const AiBranch(index: 0, total: 1)));
      expect(find.text('1/1'), findsNothing);
    });

    testWidgets('AiImage builds with a url', (tester) async {
      await tester.pumpWidget(
        _wrap(AiImage(url: Uri.parse('https://example.com/a.png'))),
      );
      expect(find.byType(AiImage), findsOneWidget);
    });
  });

  group('input & more', () {
    testWidgets('AiComposer shows attach, model, and voice affordances',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AiComposer(
            onSend: (_) {},
            onAttach: () {},
            onVoice: () {},
            modelSelector: const Text('GPT-4o'),
            attachments: const [
              FilePart(mediaType: 'application/pdf', name: 'a.pdf'),
            ],
            onRemoveAttachment: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.text('GPT-4o'), findsOneWidget);
      expect(find.text('a.pdf'), findsOneWidget); // staged attachment preview
    });

    testWidgets('AiModelSelector shows selection and opens a picker',
        (tester) async {
      String? chosen;
      await tester.pumpWidget(
        _wrap(
          AiModelSelector(
            selectedId: 'fast',
            onSelected: (id) => chosen = id,
            models: const [
              AiModelOption(id: 'fast', label: 'Fast'),
              AiModelOption(id: 'smart', label: 'Smart'),
            ],
          ),
        ),
      );
      expect(find.text('Fast'), findsOneWidget);
      await tester.tap(find.text('Fast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart'));
      await tester.pumpAndSettle();
      expect(chosen, 'smart');
    });

    testWidgets('AiConfirmation fires confirm/deny', (tester) async {
      var allowed = false;
      await tester.pumpWidget(
        _wrap(
          AiConfirmation(
            title: 'Send the email?',
            onConfirm: () => allowed = true,
          ),
        ),
      );
      expect(find.text('Send the email?'), findsOneWidget);
      await tester.tap(find.text('Allow'));
      expect(allowed, isTrue);
    });

    testWidgets('AiContextMeter formats usage', (tester) async {
      await tester.pumpWidget(
        _wrap(const AiContextMeter(usedTokens: 12345, totalTokens: 128000)),
      );
      expect(find.text('12.3k / 128.0k'), findsOneWidget);
    });

    testWidgets('AiShimmer builds', (tester) async {
      await tester.pumpWidget(_wrap(const AiShimmer(lines: 2)));
      expect(find.byType(AiShimmer), findsOneWidget);
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

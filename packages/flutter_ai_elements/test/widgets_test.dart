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
  group('AiWidgetRegistry (generative UI)', () {
    testWidgets('renders a registered dataType and falls back otherwise',
        (tester) async {
      final registry = AiWidgetRegistry()
        ..register(
          'weather',
          (context, data) => Text('It is ${data['temp']}°'),
        );

      await tester.pumpWidget(
        _wrap(
          AiDataView(
            part: const DataPart(dataType: 'weather', data: {'temp': 21}),
            registry: registry,
          ),
        ),
      );
      expect(find.text('It is 21°'), findsOneWidget);

      // Unregistered type → fallback.
      await tester.pumpWidget(
        _wrap(
          AiDataView(
            part: const DataPart(dataType: 'unknown', data: {}),
            registry: registry,
            fallback: const Text('unsupported'),
          ),
        ),
      );
      expect(find.text('unsupported'), findsOneWidget);
    });
  });

  group('AiLocalizations', () {
    test('delegate serves provided strings and reloads on change', () async {
      const custom = AiLocalizations(copy: 'Copier', send: 'Envoyer');
      const delegate = AiLocalizationsDelegate(custom);
      expect(delegate.isSupported(const Locale('fr')), isTrue);
      final loaded = await delegate.load(const Locale('fr'));
      expect(loaded.copy, 'Copier');
      expect(loaded.send, 'Envoyer');
      expect(delegate.shouldReload(const AiLocalizationsDelegate()), isTrue);
    });

    testWidgets('widgets read overridden strings from the tree',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AiLocalizationsDelegate(AiLocalizations(retry: 'Réessayer')),
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: Scaffold(
            body: AiErrorBanner(message: 'boom', onRetry: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('AiLocalizationsScope overrides strings without a delegate',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiLocalizationsScope(
            strings: AiLocalizations(allow: 'Autoriser', deny: 'Refuser'),
            child: AiConfirmation(title: 'Proceed?'),
          ),
        ),
      );
      expect(find.text('Autoriser'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
    });
  });

  group('AiChatView', () {
    testWidgets('composes transcript + input from a controller',
        (tester) async {
      final controller = UseChatController(provider: _EchoProvider());
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(AiChatView(controller: controller)));
      expect(find.byType(AiChat), findsOneWidget);
      expect(find.byType(AiPromptInput), findsOneWidget);
    });
  });

  group('AiConversationList', () {
    testWidgets('lists threads and fires select/new/delete', (tester) async {
      ChatThread? selected;
      var created = 0;
      ChatThread? deleted;
      await tester.pumpWidget(
        _wrap(
          AiConversationList(
            threads: const [
              ChatThread(id: '1', title: 'Lisbon trip'),
              ChatThread(id: '2', title: 'Dinner recipe'),
            ],
            selectedId: '1',
            onSelect: (t) => selected = t,
            onNew: () => created++,
            onDelete: (t) => deleted = t,
          ),
        ),
      );

      expect(find.text('Lisbon trip'), findsOneWidget);
      expect(find.text('Dinner recipe'), findsOneWidget);

      await tester.tap(find.text('New chat'));
      expect(created, 1);

      await tester.tap(find.text('Dinner recipe'));
      expect(selected?.id, '2');

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      expect(deleted?.id, '1');
    });
  });

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
      // Directional so it mirrors correctly under RTL (end == right in LTR).
      expect(align.alignment, AlignmentDirectional.centerEnd);
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

    testWidgets('pins the just-sent question to the top of the viewport',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final longText = List.filled(
        16,
        'This is a fairly long prior line of the conversation.',
      ).join(' ');
      final initial = AiConversation(
        id: 'c',
        messages: [
          for (var i = 0; i < 4; i++) ...[
            AiMessage(
              id: 'u$i',
              role: AiRole.user,
              parts: [TextPart('Question $i')],
            ),
            AiMessage(
              id: 'a$i',
              role: AiRole.assistant,
              parts: [TextPart(longText)],
              status: AiMessageStatus.complete,
            ),
          ],
        ],
      );
      final controller =
          UseChatController(provider: _EchoProvider(), initial: initial);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(AiChat(controller: controller)));
      await tester.pumpAndSettle();
      await controller.sendText('the new question');
      await tester.pumpAndSettle();

      // The question must sit near the top of the chat (pinned), not mid-screen
      // showing previous answers above it.
      final chatTop = tester.getTopLeft(find.byType(AiChat)).dy;
      final qTop = tester.getTopLeft(find.text('the new question')).dy;
      expect(qTop - chatTop, lessThan(80),
          reason:
              'question should be pinned to the top, was ${qTop - chatTop}px '
              'below the top');
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

    testWidgets('AiSources collapses past maxVisible and expands on tap',
        (tester) async {
      final sources = [
        for (var i = 0; i < 10; i++)
          SourcePart(url: Uri.parse('https://site$i.example')),
      ];
      await tester
          .pumpWidget(_wrap(AiSources(sources: sources, maxVisible: 3)));
      // Only the first 3 chips show, plus a "+7 more" toggle.
      expect(find.text('site0.example'), findsOneWidget);
      expect(find.text('site2.example'), findsOneWidget);
      expect(find.text('site3.example'), findsNothing);
      expect(find.text('+7 more'), findsOneWidget);

      await tester.tap(find.text('+7 more'));
      await tester.pumpAndSettle();
      expect(find.text('site9.example'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);
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
      await tester.tap(find.byIcon(Icons.refresh_rounded));
      expect(regenerated, isTrue);
    });

    testWidgets('AiAnimatedResponse reveals the full text over time',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const AiAnimatedResponse(text: 'Hello world')),
      );
      // Let the reveal ticker run to completion.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hello world'), findsOneWidget);
    });

    testWidgets('AiAnimatedResponse accelerates to drain a large backlog',
        (tester) async {
      final long = List.filled(200, 'word').join(' '); // ~1000 chars
      await tester.pumpWidget(
        _wrap(SingleChildScrollView(child: AiAnimatedResponse(text: long))),
      );
      int shownChars() =>
          (tester.state(find.byType(AiAnimatedResponse)) as dynamic).shownChars
              as int;
      await tester.pump(const Duration(milliseconds: 100)); // baseline tick
      await tester.pump(const Duration(milliseconds: 100));
      // The 120 cps floor alone would reveal only ~24 chars in 200ms; the
      // catch-up rate drains the large backlog far faster (~100 chars here) so
      // the reveal never trails a fast stream by much.
      expect(shownChars(), greaterThan(60));
      await tester.pumpAndSettle();
      expect(shownChars(), long.length);
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

    testWidgets('AiResponse applies a code highlighter when provided',
        (tester) async {
      String? seenCode;
      String? seenLanguage;
      List<TextSpan>? highlight(String code, String? language, TextStyle base) {
        seenCode = code;
        seenLanguage = language;
        return [TextSpan(text: code, style: base)];
      }

      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: AiResponse(
              text: '```dart\nfinal x = 1;\n```',
              codeHighlighter: highlight,
            ),
          ),
        ),
      );

      expect(seenCode, 'final x = 1;');
      expect(seenLanguage, 'dart');
      expect(find.byType(AiCodeBlock), findsOneWidget);
    });

    testWidgets('AiResponse renders a Markdown table', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SingleChildScrollView(
            child: AiResponse(
              text: '| Model | Speed |\n'
                  '| --- | --- |\n'
                  '| Flash | Fast |\n'
                  '| Pro | Slower |',
            ),
          ),
        ),
      );
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Model'), findsOneWidget); // header cell
      expect(find.text('Flash'), findsOneWidget); // body cell
      expect(find.text('Slower'), findsOneWidget);
    });

    testWidgets('AiResponse updates when its text changes (cache refresh)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const SingleChildScrollView(child: AiResponse(text: 'first'))),
      );
      expect(find.text('first'), findsOneWidget);
      // Re-pump with new text: the cached tree must be rebuilt (didUpdateWidget).
      await tester.pumpWidget(
        _wrap(const SingleChildScrollView(child: AiResponse(text: 'second'))),
      );
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('AiResponse renders a partial-heading prefix without hanging',
        (tester) async {
      // A streamed prefix can end on a lone `#` before its space/text arrive.
      // The block parser must still make forward progress (no infinite loop /
      // OOM) and treat it as text.
      await tester.pumpWidget(
        _wrap(const SingleChildScrollView(child: AiResponse(text: 'Intro\n#'))),
      );
      expect(find.byType(AiResponse), findsOneWidget);
      // The completed heading then renders as a heading once it arrives.
      await tester.pumpWidget(
        _wrap(const SingleChildScrollView(
          child: AiResponse(text: 'Intro\n# Title'),
        )),
      );
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('AiResponse does not italicize "2 * 3" or snake_case',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: AiResponse(
              text: 'compute 2 * 3 with snake_case and a '
                  '[link](https://example.com)',
              onLinkTap: (_) => taps++,
            ),
          ),
        ),
      );
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      var sawItalic = false;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.style?.fontStyle == FontStyle.italic) {
          sawItalic = true;
        }
        return true;
      });
      expect(sawItalic, isFalse);
      expect(taps, 0); // sanity: link present, callback wired but untapped
    });

    testWidgets('AiChainOfThought reveals steps when expanded', (tester) async {
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

    testWidgets('AiBranch shows position and hides when single',
        (tester) async {
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
    testWidgets('AiComposer shows attach, mic, and live affordances',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AiComposer(
            onSend: (_) {},
            onAttach: () {},
            onVoice: () {},
            onLive: () {},
            attachments: const [
              FilePart(mediaType: 'application/pdf', name: 'a.pdf'),
            ],
            onRemoveAttachment: (_) {},
          ),
        ),
      );
      expect(find.byIcon(Icons.add), findsOneWidget);
      // Empty field: mic (secondary) + Live (main).
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
      expect(find.text('a.pdf'), findsOneWidget); // staged attachment preview
    });

    testWidgets('AiComposer swaps Live for Send once typing', (tester) async {
      await tester.pumpWidget(
        _wrap(AiComposer(onSend: (_) {}, onVoice: () {}, onLive: () {})),
      );
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle(); // let the main-button icon morph finish
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsNothing);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing); // mic hidden
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

    testWidgets('AiModelSelector exposes a labelled button to a11y',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          AiModelSelector(
            selectedId: 'fast',
            onSelected: (_) {},
            models: const [AiModelOption(id: 'fast', label: 'Fast')],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Fast')),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Select model, Fast\nFast',
        ),
      );
      handle.dispose();
    });

    testWidgets('AiModelSelector renders nothing (no crash) with no models',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AiModelSelector(
              selectedId: 'x', onSelected: (_) {}, models: const []),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AiModelSelector), findsOneWidget);
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

    testWidgets('AiLiveSession shows status and ends', (tester) async {
      var ended = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 500,
            child: AiLiveSession(
              onEnd: () => ended = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Listening'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      expect(ended, isTrue);
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

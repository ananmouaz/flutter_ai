import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(
  Widget child, {
  double width = 400,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  bool disableAnimations = false,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    );

const _prompts = [
  'Plan a weekend in Lisbon',
  'Compare two flights',
  'Draft a packing list for a rainy trip',
  'Find a vegetarian dinner nearby',
];

void main() {
  group('AiSuggestions layouts', () {
    testWidgets('list rows are full-width buttons that report their text',
        (tester) async {
      String? picked;
      await tester.pumpWidget(_wrap(AiSuggestions(
        suggestions: _prompts,
        layout: AiSuggestionsLayout.list,
        onSelected: (s) => picked = s,
      )));
      final row = find.ancestor(
        of: find.text('Compare two flights'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(row).width, closeTo(400 - 24, 0.1));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.text('Compare two flights')),
        matchesSemantics(
          label: 'Compare two flights',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.text('Compare two flights'));
      expect(picked, 'Compare two flights');
    });

    testWidgets('null onSelected disables every suggestion', (tester) async {
      await tester.pumpWidget(_wrap(const AiSuggestions(
        suggestions: _prompts,
        layout: AiSuggestionsLayout.list,
        onSelected: null,
      )));
      for (final ink in tester.widgetList<InkWell>(find.byType(InkWell))) {
        expect(ink.onTap, isNull);
      }
    });

    testWidgets('list arrow mirrors in RTL', (tester) async {
      await tester.pumpWidget(_wrap(
        const AiSuggestions(
          suggestions: _prompts,
          layout: AiSuggestionsLayout.list,
          onSelected: null,
        ),
        direction: TextDirection.rtl,
      ));
      final flip = tester.widget<Transform>(find
          .ancestor(
            of: find.byIcon(Icons.subdirectory_arrow_right_rounded).first,
            matching: find.byType(Transform),
          )
          .first);
      expect(flip.transform.entry(0, 0), -1);
    });

    testWidgets('grid uses two columns, or one when narrow or scaled',
        (tester) async {
      double dx(String text) => tester.getTopLeft(find.text(text)).dx;

      await tester.pumpWidget(_wrap(AiSuggestions(
        suggestions: _prompts,
        layout: AiSuggestionsLayout.grid,
        onSelected: (_) {},
      )));
      expect(dx(_prompts[1]), greaterThan(dx(_prompts[0])));
      // Cards in a row share one height even when their text wraps.
      Size card(String text) => tester.getSize(find
          .ancestor(of: find.text(text), matching: find.byType(InkWell))
          .first);
      expect(card(_prompts[2]).height, card(_prompts[3]).height);

      await tester.pumpWidget(_wrap(
        AiSuggestions(
          suggestions: _prompts,
          layout: AiSuggestionsLayout.grid,
          onSelected: (_) {},
        ),
        width: 320,
        textScale: 2,
      ));
      expect(dx(_prompts[1]), dx(_prompts[0]));
      expect(tester.takeException(), isNull);
    });
  });

  group('AiConfirmation status', () {
    Widget card(
      AiConfirmationStatus status, {
      bool disableAnimations = false,
    }) =>
        _wrap(
          AiConfirmation(
            title: 'Book the hotel?',
            status: status,
            onConfirm: () {},
            onDeny: () {},
          ),
          disableAnimations: disableAnimations,
        );

    testWidgets('only the awaiting state offers the buttons', (tester) async {
      await tester.pumpWidget(card(AiConfirmationStatus.awaiting));
      expect(find.text('Allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);

      for (final (status, label) in [
        (AiConfirmationStatus.submitting, 'Sending your decision…'),
        (AiConfirmationStatus.approved, 'Approved'),
        (AiConfirmationStatus.denied, 'Denied'),
        (AiConfirmationStatus.expired, 'Expired · no action was taken'),
      ]) {
        await tester.pumpWidget(card(status));
        expect(find.text('Allow'), findsNothing, reason: '$status');
        expect(find.text('Deny'), findsNothing, reason: '$status');
        expect(find.text(label), findsOneWidget, reason: '$status');
      }
    });

    testWidgets('submitting progress is static under reduced motion',
        (tester) async {
      await tester.pumpWidget(card(AiConfirmationStatus.submitting));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(
        card(AiConfirmationStatus.submitting, disableAnimations: true),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('settled status is a live region and keeps the card height',
        (tester) async {
      await tester.pumpWidget(card(AiConfirmationStatus.awaiting));
      final before = tester.getSize(find.byType(AiConfirmation)).height;
      await tester.pumpWidget(card(AiConfirmationStatus.approved));
      expect(tester.getSize(find.byType(AiConfirmation)).height, before);
      expect(
        tester.getSemantics(find.text('Approved')),
        matchesSemantics(label: 'Approved', isLiveRegion: true),
      );
    });

    testWidgets('settled strings are localizable', (tester) async {
      await tester.pumpWidget(_wrap(const AiLocalizationsScope(
        strings: AiLocalizations(confirmationApproved: 'Approuvé'),
        child: AiConfirmation(
          title: 'Réserver ?',
          status: AiConfirmationStatus.approved,
        ),
      )));
      expect(find.text('Approuvé'), findsOneWidget);
    });
  });

  testWidgets('answered question shows a settled check', (tester) async {
    await tester.pumpWidget(_wrap(AiQuestion(
      prompt: 'Pick one',
      options: const [AiQuestionOption(value: 'a', label: 'Alpha')],
      answer: AiQuestionResponse(selectedValues: ['a']),
    )));
    expect(find.text('Answered: Alpha'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('composer capitalizes sentences on soft keyboards',
      (tester) async {
    await tester.pumpWidget(_wrap(AiComposer(onSend: (_) {})));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textCapitalization, TextCapitalization.sentences);
  });

  testWidgets('prompt input focus node lets the host open the keyboard',
      (tester) async {
    final controller = UseChatController(provider: const _NoopProvider());
    final focus = FocusNode();
    final text = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    addTearDown(text.dispose);
    await tester.pumpWidget(_wrap(AiPromptInput(
      controller: controller,
      textController: text,
      focusNode: focus,
    )));
    text.text = 'Move it to 11:00';
    focus.requestFocus();
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('Move it to 11:00'), findsOneWidget);
  });

  testWidgets('parts hidden by a part builder leave no gap', (tester) async {
    Future<double> gap(List<AiPart> parts) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiMessageBubble(
            message: AiMessage(
              id: 'a',
              role: AiRole.assistant,
              status: AiMessageStatus.complete,
              parts: parts,
            ),
            partBuilder: (context, part, message) =>
                part is TextPart ? Text(part.text) : const SizedBox.shrink(),
          ),
        ),
      ));
      return tester.getTopLeft(find.text('second')).dy -
          tester.getBottomLeft(find.text('first')).dy;
    }

    final plain = await gap(const [TextPart('first'), TextPart('second')]);
    final hidden = await gap([
      const TextPart('first'),
      for (var i = 0; i < 4; i++)
        SourcePart(url: Uri.parse('https://example.com/$i')),
      const TextPart('second'),
    ]);
    expect(plain, 8);
    expect(hidden, plain);
  });

  testWidgets('conversation view forwards keyboard dismissal', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AiConversationView(
          messages: [
            AiMessage(id: 'u1', role: AiRole.user, parts: [TextPart('Hi')]),
          ],
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        ),
      ),
    ));
    expect(
      tester.widget<ListView>(find.byType(ListView)).keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });
}

class _NoopProvider implements LlmProvider {
  const _NoopProvider();

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) =>
      const Stream.empty();
}

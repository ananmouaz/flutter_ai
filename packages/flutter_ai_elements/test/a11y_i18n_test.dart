import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {TextDirection? direction, double textScale = 1}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction ?? TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: child),
        ),
      ),
    );

const _fr = AiLocalizations(
  toolArguments: 'Arguments (fr)',
  toolResult: 'Résultat',
  toolError: 'Erreur',
  contextLabel: 'Contexte',
  chainOfThought: 'Fil de pensée',
  showLess: 'Voir moins',
  removeAttachment: 'Retirer la pièce jointe',
);

void main() {
  group('i18n — strings that used to be hardcoded English', () {
    testWidgets('AiToolInvocation section labels come from AiLocalizations',
        (tester) async {
      Widget card(ToolResultPart? result) => AiToolInvocation(
            call: const ToolCallPart(
              toolCallId: 'c1',
              toolName: 'get_weather',
              args: {'city': 'Paris'},
            ),
            result: result,
            initiallyExpanded: true,
          );

      await tester.pumpWidget(_wrap(card(null)));
      expect(find.text('Arguments'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          AiLocalizationsScope(
            strings: _fr,
            child: card(
              const ToolResultPart(toolCallId: 'c1', result: {'temp': 21}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Arguments (fr)'), findsOneWidget);
      expect(find.text('Résultat'), findsOneWidget);
      expect(find.text('Result'), findsNothing);
    });

    testWidgets('AiToolInvocation uses the error label for an error result',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiLocalizationsScope(
            strings: _fr,
            child: AiToolInvocation(
              call: ToolCallPart(toolCallId: 'c1', toolName: 't', args: {}),
              result: ToolResultPart(
                toolCallId: 'c1',
                result: 'boom',
                isError: true,
              ),
              initiallyExpanded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Erreur'), findsOneWidget);
    });

    testWidgets('AiContextMeter label defaults to l10n and can be overridden',
        (tester) async {
      const meter = AiContextMeter(usedTokens: 10, totalTokens: 100);

      await tester.pumpWidget(_wrap(meter));
      expect(find.text('Context'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(const AiLocalizationsScope(strings: _fr, child: meter)),
      );
      expect(find.text('Contexte'), findsOneWidget);

      // An explicit label still wins over the localization.
      await tester.pumpWidget(
        _wrap(
          const AiLocalizationsScope(
            strings: _fr,
            child: AiContextMeter(
              usedTokens: 10,
              totalTokens: 100,
              label: 'Window',
            ),
          ),
        ),
      );
      expect(find.text('Window'), findsOneWidget);
    });

    testWidgets('AiChainOfThought title falls back to l10n.chainOfThought',
        (tester) async {
      const steps = [AiThoughtStep(label: 'search')];

      await tester.pumpWidget(_wrap(const AiChainOfThought(steps: steps)));
      expect(find.text('Chain of thought'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          const AiLocalizationsScope(
            strings: _fr,
            child: AiChainOfThought(steps: steps),
          ),
        ),
      );
      expect(find.text('Fil de pensée'), findsOneWidget);
    });

    testWidgets('AiSources expand/collapse labels come from AiLocalizations',
        (tester) async {
      final sources = [
        for (var i = 0; i < 5; i++)
          SourcePart(url: Uri.parse('https://example.com/$i')),
      ];

      await tester.pumpWidget(
        _wrap(AiSources(sources: sources, maxVisible: 2)),
      );
      expect(find.text('+3 more'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          AiLocalizationsScope(
            strings: AiLocalizations(
              showLess: _fr.showLess,
              moreSources: (n) => 'encore $n',
            ),
            child: AiSources(sources: sources, maxVisible: 2),
          ),
        ),
      );
      expect(find.text('encore 3'), findsOneWidget);

      await tester.tap(find.text('encore 3'));
      await tester.pumpAndSettle();
      expect(find.text('Voir moins'), findsOneWidget);
    });
  });

  group('a11y — touch targets and contrast', () {
    testWidgets('attachment remove badge is a labelled 44px target',
        (tester) async {
      var removed = false;
      await tester.pumpWidget(
        _wrap(
          AiLocalizationsScope(
            strings: _fr,
            child: AiComposer(
              onSend: (_) {},
              attachments: const [
                FilePart(mediaType: 'text/plain', name: 'notes.txt'),
              ],
              onRemoveAttachment: (_) => removed = true,
            ),
          ),
        ),
      );

      final badge = find.ancestor(
        of: find.byIcon(Icons.close),
        matching: find.byType(InkResponse),
      );
      expect(tester.getSize(badge), const Size(44, 44));
      expect(
        find.bySemanticsLabel('Retirer la pièce jointe'),
        findsOneWidget,
      );

      await tester.tap(badge);
      expect(removed, isTrue);
    });

    testWidgets('caution confirm button does not paint white on amber',
        (tester) async {
      final theme = AiThemeExtension.fallback();
      await tester.pumpWidget(
        _wrap(
          Theme(
            data: ThemeData(extensions: [theme]),
            child: AiConfirmation(
              title: 'Delete the file?',
              tone: AiConfirmationTone.caution,
              onConfirm: () {},
              onDeny: () {},
            ),
          ),
        ),
      );

      final label = tester.widget<Text>(find.text('Allow'));
      final color = label.style!.color!;
      expect(color, isNot(theme.onAccentColor));
      // Dark text on the amber fill: contrast well above the 2.2:1 the white
      // pairing produced.
      expect(
        ThemeData.estimateBrightnessForColor(color),
        Brightness.dark,
      );
    });

    testWidgets('confirm buttons grow with the text scale instead of clipping',
        (tester) async {
      Widget card(double scale) => _wrap(
            AiConfirmation(
              title: 'Delete the file?',
              onConfirm: () {},
              onDeny: () {},
            ),
            textScale: scale,
          );

      await tester.pumpWidget(card(1));
      final normal = tester.getSize(
        find.ancestor(
          of: find.text('Allow'),
          matching: find.byType(InkWell),
        ),
      );

      await tester.pumpWidget(card(2));
      await tester.pumpAndSettle();
      final scaled = tester.getSize(
        find.ancestor(
          of: find.text('Allow'),
          matching: find.byType(InkWell),
        ),
      );

      expect(normal.height, greaterThanOrEqualTo(40));
      expect(scaled.height, greaterThan(normal.height));
      expect(tester.takeException(), isNull);
    });
  });

  group('RTL', () {
    testWidgets('blockquote border and padding follow the text direction',
        (tester) async {
      Widget quote(TextDirection direction) => _wrap(
            const AiResponse(text: '> quoted'),
            direction: direction,
          );

      await tester.pumpWidget(quote(TextDirection.ltr));
      final ltrQuote = tester.widget<Container>(
        find
            .ancestor(
              of: find.textContaining('quoted'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(ltrQuote.padding, isA<EdgeInsetsDirectional>());
      expect(
        (ltrQuote.decoration! as BoxDecoration).border,
        isA<BorderDirectional>(),
      );

      // Same widget in RTL must not throw and keeps the directional border.
      await tester.pumpWidget(quote(TextDirection.rtl));
      expect(tester.takeException(), isNull);
    });

    testWidgets('streaming loader aligns to the start, not the left',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AiConversationView(
            messages: [
              AiMessage(
                id: 'u1',
                role: AiRole.user,
                parts: [TextPart('hi')],
              ),
            ],
            showLoader: true,
          ),
          direction: TextDirection.rtl,
        ),
      );
      // The loader animates forever — pump a frame, never pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 50));

      final align = tester.widget<Align>(
        find
            .ancestor(
              of: find.byType(AiLoader),
              matching: find.byType(Align),
            )
            .first,
      );
      expect(align.alignment, AlignmentDirectional.centerStart);
    });
  });
}

import 'dart:async';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = [
  AiQuestionOption(value: 'a', label: 'Alpha'),
  AiQuestionOption(value: 'b', label: 'Beta'),
];
Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('single choice replaces selection and submits immutable values',
      (tester) async {
    AiQuestionResponse? result;
    await tester.pumpWidget(_wrap(AiQuestion(
        prompt: 'Choose',
        options: _options,
        onSubmit: (value) => result = value)));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pumpAndSettle();
    expect(result!.selectedValues, ['b']);
    expect(() => result!.selectedValues.add('c'), throwsUnsupportedError);
    expect(find.text('Answered: Beta'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('enabling the submit button shows its label at once',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [AiThemeExtension.fallback()]),
        home: Scaffold(
            body: AiQuestion(
                prompt: 'Choose', options: _options, onSubmit: (_) {}))));
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    // The background switches to the accent color in this frame, so the label
    // must too; a fading label is unreadable on the new background.
    final label = tester.renderObject<RenderParagraph>(find.text('Answer'));
    expect(label.text.style?.color, AiThemeExtension.fallback().onAccentColor);
  });

  testWidgets('multiple choices toggle independently and text is trimmed',
      (tester) async {
    AiQuestionResponse? result;
    await tester.pumpWidget(_wrap(AiQuestion(
        prompt: 'Choose',
        options: _options,
        selectionMode: AiQuestionSelectionMode.multiple,
        allowFreeform: true,
        onSubmit: (value) => result = value)));
    await tester.tap(find.text('Beta'));
    await tester.pump();
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  context  ');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pumpAndSettle();
    expect(result!.selectedValues, ['b']);
    expect(result!.text, 'context');
  });

  testWidgets('freeform rejects whitespace and supports text-only response',
      (tester) async {
    AiQuestionResponse? result;
    await tester.pumpWidget(_wrap(AiQuestion(
        prompt: 'Why?',
        allowFreeform: true,
        onSubmit: (value) => result = value)));
    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), 'Useful');
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pumpAndSettle();
    expect(result!.selectedValues, isEmpty);
    expect(result!.text, 'Useful');
  });

  testWidgets('pending blocks duplicate taps; failure retains draft for retry',
      (tester) async {
    var attempts = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(_wrap(AiQuestion(
        prompt: 'Choose',
        options: _options,
        onSubmit: (_) {
          attempts++;
          return attempts == 1 ? pending.future : Future<void>.value();
        })));
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.tap(find.text('Answer'));
    await tester.pump();
    expect(attempts, 1);
    expect(find.text('Submitting…'), findsOneWidget);
    pending.completeError(StateError('private details'));
    await tester.pumpAndSettle();
    expect(find.text('Could not submit your answer. Please try again.'),
        findsOneWidget);
    expect(find.textContaining('private details'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Answered: Alpha'), findsOneWidget);
  });

  testWidgets('late completion after disposal is harmless', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(_wrap(AiQuestion(
        prompt: 'Choose', options: _options, onSubmit: (_) => pending.future)));
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.tap(find.text('Answer'));
    await tester.pumpWidget(_wrap(const SizedBox()));
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('restored answer and host-disabled pending state are inert',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_wrap(AiQuestion(
        prompt: 'Choose',
        options: _options,
        answer: AiQuestionResponse(selectedValues: ['a']),
        onSubmit: (_) => calls++)));
    expect(find.text('Answered: Alpha'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    await tester.pumpWidget(_wrap(AiQuestion(
        key: const ValueKey('new'),
        prompt: 'Choose',
        options: _options,
        enabled: false,
        onSubmit: (_) => calls++)));
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(calls, 0);
  });

  testWidgets('options expose checked semantics and keyboard activation',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(
        AiQuestion(prompt: 'Choose', options: _options, onSubmit: (_) {})));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final flags = tester
        .getSemantics(find.text('Alpha'))
        .getSemanticsData()
        .flagsCollection;
    expect(flags.isChecked, CheckedState.isTrue);
    expect(flags.isInMutuallyExclusiveGroup, true);
    handle.dispose();
  });

  testWidgets(
      'localized, narrow, RTL, large text and dark mode do not overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
                textScaler: TextScaler.linear(2), disableAnimations: true),
            child: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  child: AiLocalizationsScope(
                      strings: const AiLocalizations(
                          questionAnswer: 'Répondre',
                          questionInputLabel: 'Votre réponse'),
                      child: AiQuestion(
                          prompt: 'A long question with room for wrapping',
                          options: const [
                            AiQuestionOption(
                                value: 'long',
                                label:
                                    'A long answer that wraps onto several lines'),
                          ],
                          allowFreeform: true,
                          onSubmit: (_) {})),
                )),
          ),
        )));
    expect(find.text('Répondre'), findsOneWidget);
    expect(find.text('Votre réponse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

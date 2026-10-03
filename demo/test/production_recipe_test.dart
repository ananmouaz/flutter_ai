import 'package:flutter/material.dart';
import 'package:flutter_ai_demo/production/production_app.dart';
import 'package:flutter_ai_demo/production/production_chat.dart';
import 'package:flutter_ai_demo/production/production_provider.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

// Interaction checks for the production recipe: every state of the
// ask → progress → answer/sources → follow-up journey, plus approval,
// question and result-card outcomes.

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProductionAgentApp(
      home: ProductionChatScreen(
        provider: ProductionAgentProvider(
          delay: const Duration(milliseconds: 10),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Advances the scripted stream by [ms] milliseconds in small frames.
Future<void> _run(WidgetTester tester, [int ms = 2500]) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Scrolls [finder] into view, then taps it.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Finder _activeStep() => find.byWidgetPredicate(
  (w) => w is AiTask && w.items.any((i) => i.status == AiTaskStatus.active),
);

void main() {
  testWidgets('empty → progress → answer → sources → follow-up', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(find.text('What can I help with?'), findsOneWidget);
    for (final starter in productionStarters) {
      expect(find.text(starter), findsOneWidget);
    }

    await tester.tap(find.text('Compare weekend trains to Porto'));
    await _run(tester, 120);
    // Progress comes from tool state and reads as an action, not reasoning.
    expect(_activeStep(), findsOneWidget);
    expect(find.textContaining('Alfa Pendular'), findsNothing);

    await _run(tester);
    expect(_activeStep(), findsNothing);
    expect(find.text('3 steps completed'), findsOneWidget);
    expect(find.textContaining('Alfa Pendular AP 133'), findsOneWidget);

    // Diagnostics stay hidden until asked for.
    expect(find.byType(AiToolGroup), findsNothing);

    await _tapVisible(tester, find.bySemanticsLabel('Show 4 sources'));
    await tester.pumpAndSettle();
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('CP train times'), findsOneWidget);
    expect(find.text('www.seat61.com'), findsOneWidget);
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();

    const followUp = 'What can I see in Porto in one day?';
    expect(find.text(followUp), findsOneWidget);
    await _tapVisible(tester, find.text(followUp));
    await tester.pump();
    // The earlier follow-ups give way to the new turn (no stale taps).
    expect(
      find.text('Is first class worth it on the Alfa Pendular?'),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AiMessageBubble),
        matching: find.text(followUp),
      ),
      findsOneWidget,
    );
    await _run(tester);
  });

  testWidgets('a failed run shows retry and settles after it', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Check flight TP 1350'));
    await _run(tester);
    expect(find.textContaining("Couldn't finish:"), findsOneWidget);
    expect(find.text("Couldn't finish"), findsOneWidget);
    expect(_activeStep(), findsNothing);

    await tester.tap(find.text('Retry'));
    await _run(tester);
    expect(find.textContaining("Couldn't finish"), findsNothing);
    expect(find.text('1 step completed'), findsOneWidget);
    expect(find.textContaining('is on time'), findsOneWidget);
  });

  testWidgets('a question answer survives scrolling and yields a result card', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Remind me to renew my passport'));
    await _run(tester);
    expect(find.text('When should I remind you?'), findsOneWidget);

    await _tapVisible(tester, find.text('A month before'));
    await tester.pump();
    await _tapVisible(tester, find.text('Answer'));
    await tester.pump();
    expect(find.text('Submitting…'), findsOneWidget);
    await _run(tester);
    expect(find.text('Answered: A month before'), findsOneWidget);
    expect(find.text('Renew your passport'), findsOneWidget);

    // Edit prefills the composer and opens the keyboard.
    await _tapVisible(tester, find.text('Edit'));
    await tester.pump();
    expect(find.text('Change the reminder to '), findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);

    await _tapVisible(tester, find.text('Add'));
    await tester.pump();
    expect(find.text('Added to your reminders'), findsOneWidget);
    expect(find.text('Add'), findsNothing);

    // Push the question out of the lazy list, then come back to it.
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -3000));
    await tester.pump();
    await tester.drag(list, const Offset(0, 3000));
    await tester.pump();
    expect(find.text('Answered: A month before'), findsOneWidget);
    expect(find.text('Answer'), findsNothing);
  });

  group('approval', () {
    Future<void> reachApproval(WidgetTester tester) async {
      await _pumpApp(tester);
      await tester.tap(find.text('Book a table for two tonight'));
      await _run(tester);
      expect(find.text('Book Taberna da Rua at 20:00?'), findsOneWidget);
      expect(find.text('Waiting for your approval'), findsWidgets);
    }

    testWidgets('approving runs the booking and settles the card', (
      tester,
    ) async {
      await reachApproval(tester);
      await _tapVisible(tester, find.text('Book'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Sending your decision…'), findsOneWidget);
      await _run(tester);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Book'), findsNothing);
      expect(find.textContaining('confirmation TR-2041'), findsOneWidget);
    });

    testWidgets('denying never books', (tester) async {
      await reachApproval(tester);
      await _tapVisible(tester, find.text('Not now'));
      await _run(tester);
      expect(find.text('Denied'), findsOneWidget);
      expect(find.text('Approved'), findsNothing);
      expect(find.textContaining("didn't book anything"), findsOneWidget);
    });

    testWidgets('stopping expires the request without booking', (tester) async {
      await reachApproval(tester);
      await tester.tap(find.byTooltip('Stop'));
      await _run(tester, 500);
      expect(find.text('Expired · no action was taken'), findsOneWidget);
      expect(find.text('Book'), findsNothing);
      expect(find.text('Approved'), findsNothing);
      expect(_activeStep(), findsNothing);
      expect(find.text('Stopped'), findsOneWidget);
    });

    testWidgets('a new message expires the pending request', (tester) async {
      await reachApproval(tester);
      await tester.enterText(find.byType(TextField), 'Never mind');
      await tester.pump();
      // While the agent waits, the main button is Stop; the keyboard's send
      // action still submits, which settles the open call.
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await _run(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pump();
      expect(find.text('Expired · no action was taken'), findsOneWidget);
      expect(find.text('Book'), findsNothing);
    });
  });

  testWidgets('tool details are behind the overflow menu', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Compare weekend trains to Porto'));
    await _run(tester);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show tool details'));
    await tester.pumpAndSettle();
    expect(find.byType(AiToolGroup), findsOneWidget);
  });
}

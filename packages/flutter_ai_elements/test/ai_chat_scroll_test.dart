import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

/// A provider that streams a multi-line assistant reply so the chat has more
/// content than fits the viewport — the case where top-pinning matters.
class _StreamingProvider implements LlmProvider {
  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    // A short reply: shorter than the viewport, so the chat must RESERVE
    // trailing space for the anchored question to reach the top.
    yield const MessageStarted(messageId: 'a-new', role: AiRole.assistant);
    yield const TextDelta(messageId: 'a-new', delta: 'Short streamed answer.');
    yield const MessageFinished(messageId: 'a-new', reason: FinishReason.stop);
  }
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AiChat top-pin scroll', () {
    testWidgets('anchors the just-sent user message to the viewport top',
        (tester) async {
      // Fix the viewport to a small phone-ish size so prior content overflows
      // and the anchor genuinely has to scroll to the top.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A backlog of prior turns, each tall enough that the transcript is far
      // taller than the 800px viewport.
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
          UseChatController(provider: _StreamingProvider(), initial: initial);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(AiChat(controller: controller)));
      await _settle(tester);

      // Send a new user turn; the assistant reply streams in below it.
      await controller.sendText('the new question');
      await _settle(tester);

      final question = find.text('the new question');
      expect(question, findsOneWidget);

      // The anchored user message must be pinned at/near the top of the AiChat
      // viewport (ChatGPT-style), NOT mid-screen with prior answers above it.
      final chatTop = tester.getTopLeft(find.byType(AiChat)).dy;
      final qTop = tester.getTopLeft(question).dy;
      expect(
        qTop - chatTop,
        lessThan(80),
        reason: 'newly-sent question should pin to the top, was '
            '${qTop - chatTop}px below the chat top',
      );

      // Trailing space must be reserved beneath the last item so the anchor can
      // reach the top even though the streamed answer is shorter than the
      // viewport. The reservation lives on AiConversationView.trailingSpace.
      final view = tester.widget<AiConversationView>(
        find.byType(AiConversationView),
      );
      expect(
        view.trailingSpace,
        greaterThan(0),
        reason: 'trailing space must be reserved so the anchor can reach the '
            'top, was ${view.trailingSpace}',
      );
      // The view must have an anchor wired up (the just-sent user message),
      // matching the id of the controller's last user message.
      final lastUserId =
          controller.messages.lastWhere((m) => m.role == AiRole.user).id;
      expect(view.anchorId, lastUserId);
    });
  });
}

/// Pumps a bounded number of frames so [AiChat]'s post-frame `_settle()` retry
/// loop can run. We can't `pumpAndSettle` — the streaming caret blinks forever,
/// so the tree never reaches a steady state.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

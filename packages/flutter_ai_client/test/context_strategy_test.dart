import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_test/flutter_test.dart';

AiConversation _conv(List<AiMessage> messages) =>
    AiConversation(id: 'c', messages: messages);

AiMessage _m(String id, AiRole role, String text) =>
    AiMessage(id: id, role: role, parts: [TextPart(text)]);

void main() {
  group('keepLastWithSummary', () {
    final base = _conv([
      _m('s', AiRole.system, 'sys'),
      _m('u1', AiRole.user, 'one'),
      _m('a1', AiRole.assistant, '1'),
      _m('u2', AiRole.user, 'two'),
      _m('a2', AiRole.assistant, '2'),
      _m('u3', AiRole.user, 'three'),
    ]);

    test('injects the summary as a system message when older turns are dropped',
        () {
      final trimmed = keepLastWithSummary(
        summary: () => 'user greeted and asked two things',
        count: 2,
      )(base);

      final roles = trimmed.messages.map((m) => m.role).toList();
      // real system, injected summary system message, then last 2 (a2, u3).
      expect(roles, [
        AiRole.system,
        AiRole.system,
        AiRole.assistant,
        AiRole.user,
      ]);
      expect(trimmed.messages[1].text, contains('user greeted'));
      expect(trimmed.messages.last.id, 'u3');
    });

    test('injects nothing when nothing is dropped', () {
      final trimmed = keepLastWithSummary(
        summary: () => 'should not appear',
        count: 10,
      )(base);
      expect(trimmed, same(base));
    });

    test('injects nothing when the summary is empty', () {
      final trimmed = keepLastWithSummary(
        summary: () => '   ',
        count: 1,
      )(base);
      expect(
        trimmed.messages.where((m) => m.role == AiRole.system),
        hasLength(1), // only the real system message
      );
      expect(trimmed.messages.last.id, 'u3');
    });

    test('does not begin the kept window on an orphaned tool result', () {
      final conv = _conv([
        _m('u1', AiRole.user, 'q'),
        _m('a1', AiRole.assistant, 'call'),
        _m('t1', AiRole.tool, 'result'),
        _m('a2', AiRole.assistant, 'answer'),
      ]);
      final trimmed = keepLastWithSummary(
        summary: () => 'summary',
        count: 2, // would start on the tool result; must advance past it
      )(conv);
      expect(trimmed.messages.any((m) => m.role == AiRole.tool), isFalse);
      expect(trimmed.messages.last.id, 'a2');
      expect(trimmed.messages.any((m) => m.id == 't1'), isFalse);
    });
  });
}

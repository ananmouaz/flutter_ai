import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('MessageProcessor perf', () {
    test('accumulates 20000 single-char deltas in linear time', () {
      // Regression guard against O(n^2) text accumulation. The processor keeps
      // a StringBuffer per text part and appends in place (O(delta) per token),
      // so 20000 single-char deltas finish in milliseconds. A regression to
      // `last.text + delta` would re-copy the whole accumulated string on every
      // token — ~20000^2 / 2 ≈ 200M char-copies — taking many seconds.
      //
      // The 2-second bound is deliberately GENEROUS: it sits far above the
      // real (linear, sub-10ms) runtime yet far below a quadratic blow-up, so
      // it distinguishes the two without flaking on slow shared CI runners.
      const deltaCount = 20000;

      final processor = MessageProcessor();
      processor.apply(
        const MessageStarted(messageId: 'm1', role: AiRole.assistant),
      );

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < deltaCount; i++) {
        processor.apply(const TextDelta(messageId: 'm1', delta: 'x'));
      }
      processor.apply(
        const MessageFinished(messageId: 'm1', reason: FinishReason.stop),
      );
      stopwatch.stop();

      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 2)),
        reason: 'linear accumulation finishes in ms; a quadratic regression '
            'would take many seconds (took ${stopwatch.elapsedMilliseconds}ms)',
      );

      // The accumulated text must be exactly the concatenation of every delta.
      final message = processor.conversation.messageById('m1')!;
      expect(message.text.length, deltaCount);
      expect(message.status, AiMessageStatus.complete);
    });
  });
}

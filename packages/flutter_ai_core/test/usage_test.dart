import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:test/test.dart';

void main() {
  group('AiUsage', () {
    test('round-trips through JSON, omitting null fields', () {
      const usage = AiUsage(
        inputTokens: 100,
        outputTokens: 50,
        cachedInputTokens: 20,
        totalTokens: 150,
      );
      final json = usage.toJson();
      expect(json.containsKey('reasoningTokens'), isFalse);
      expect(AiUsage.fromJson(json), usage);
    });

    test('resolvedTotal derives from input + output when total is absent', () {
      const usage = AiUsage(inputTokens: 30, outputTokens: 12);
      expect(usage.resolvedTotal, 42);
      expect(const AiUsage().resolvedTotal, isNull);
    });

    test('operator + sums each field', () {
      const a = AiUsage(inputTokens: 10, outputTokens: 5);
      const b = AiUsage(inputTokens: 3, outputTokens: 7, totalTokens: 10);
      final sum = a + b;
      expect(sum.inputTokens, 13);
      expect(sum.outputTokens, 12);
      expect(sum.totalTokens, 10); // null + 10
    });

    test('estimateCost bills cached input at the discounted rate', () {
      const usage = AiUsage(
        inputTokens: 1000,
        cachedInputTokens: 400,
        outputTokens: 500,
      );
      // 600 uncached @ $3/M + 400 cached @ $0.3/M + 500 out @ $15/M
      final cost = usage.estimateCost(
        inputPer1M: 3,
        outputPer1M: 15,
        cachedInputPer1M: 0.3,
      );
      expect(cost, closeTo(0.0018 + 0.00012 + 0.0075, 1e-9));
    });

    test('estimateCost returns null with no token counts', () {
      expect(
        const AiUsage().estimateCost(inputPer1M: 1, outputPer1M: 1),
        isNull,
      );
    });
  });

  test('MessageFinished carries usage through JSON', () {
    const event = MessageFinished(
      messageId: 'a1',
      reason: FinishReason.stop,
      usage: AiUsage(inputTokens: 5, outputTokens: 9),
    );
    final restored = AiStreamEvent.fromJson(event.toJson()) as MessageFinished;
    expect(restored.usage?.inputTokens, 5);
    expect(restored.usage?.outputTokens, 9);
  });
}

import 'package:flutter_ai_demo/demo_provider.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each turn is a distinct, correctly ordered message', () async {
    final controller = UseChatController(
      provider: const DemoChatProvider(delay: Duration.zero),
      scheduler: (cb) => cb(),
    );
    addTearDown(controller.dispose);

    await controller.sendText('Plan a weekend in Lisbon');
    await controller.sendText('Suggest a dinner recipe');

    // Order must be user → assistant → user → assistant.
    expect(controller.messages.map((m) => m.role).toList(), [
      AiRole.user,
      AiRole.assistant,
      AiRole.user,
      AiRole.assistant,
    ]);

    // The two responses are distinct messages, not one mutated in place.
    final assistantIds = controller.messages
        .where((m) => m.role == AiRole.assistant)
        .map((m) => m.id)
        .toSet();
    expect(assistantIds.length, 2);
  });
}

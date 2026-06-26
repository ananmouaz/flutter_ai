// Streams a single completion from OpenAI and prints the assembled reply.
//
// Run with:
//   dart run --define=OPENAI_API_KEY=sk-... example/flutter_ai_provider_openai_example.dart
import 'package:flutter_ai_provider_openai/flutter_ai_provider_openai.dart';

Future<void> main() async {
  const apiKey = String.fromEnvironment('OPENAI_API_KEY');
  if (apiKey.isEmpty) {
    print('Set OPENAI_API_KEY via --define to run against the live API.');
    return;
  }

  final provider = OpenAiProvider(apiKey: apiKey);
  final processor = MessageProcessor();

  const conversation = AiConversation(
    id: 'demo',
    messages: [
      AiMessage(
        id: 'u1',
        role: AiRole.user,
        parts: [TextPart('Say hello in one short sentence.')],
      ),
    ],
  );

  await for (final event in provider.send(conversation)) {
    processor.apply(event);
  }
  print(processor.conversation.lastMessage?.text);
  provider.close();
}

// Streams a single completion and prints the assembled reply.
//
// Run with:
//   dart run --define=GEMINI_API_KEY=... example/flutter_ai_provider_gemini_example.dart
import 'package:flutter_ai_provider_gemini/flutter_ai_provider_gemini.dart';

Future<void> main() async {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  if (apiKey.isEmpty) {
    print('Set GEMINI_API_KEY via --define to run against the live API.');
    return;
  }

  final provider = GeminiProvider(apiKey: apiKey);
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

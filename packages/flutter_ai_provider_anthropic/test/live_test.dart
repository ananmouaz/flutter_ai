import 'dart:io';

import 'package:flutter_ai_provider_anthropic/flutter_ai_provider_anthropic.dart';
import 'package:test/test.dart';

/// Live smoke test against the real Gemini API. Skipped unless ANTHROPIC_API_KEY
/// is set, so it's safe in CI. Run with:
///   ANTHROPIC_API_KEY=... dart test test/live_test.dart
void main() {
  final key = Platform.environment['ANTHROPIC_API_KEY'];
  final skip = key == null ? 'set ANTHROPIC_API_KEY to run live tests' : null;

  test('streams a short reply from the live API', () async {
    final provider = AnthropicProvider(apiKey: key!);
    final processor = MessageProcessor();
    await for (final event in provider.send(
      const AiConversation(
        id: 'c',
        messages: [
          AiMessage(
            id: 'u',
            role: AiRole.user,
            parts: [TextPart('Reply with a short friendly greeting.')],
          ),
        ],
      ),
    )) {
      processor.apply(event);
    }
    final message = processor.conversation.messages.single;
    expect(message.text.trim(), isNotEmpty);
    expect(message.status, AiMessageStatus.complete);
  }, skip: skip);
}

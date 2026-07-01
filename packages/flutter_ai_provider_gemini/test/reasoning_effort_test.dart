import 'dart:convert';

import 'package:flutter_ai_provider_gemini/flutter_ai_provider_gemini.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

Future<Map<String, Object?>> _capture(AiRequestOptions options) async {
  late Map<String, Object?> payload;
  final provider = GeminiProvider(
    apiKey: 'secret',
    client: MockClient.streaming((request, bodyStream) async {
      payload = (jsonDecode(await bodyStream.bytesToString()) as Map)
          .cast<String, Object?>();
      return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
    }),
  );
  await provider
      .send(
        const AiConversation(
          id: 'c',
          messages: [
            AiMessage(id: 'm', role: AiRole.user, parts: [TextPart('Hi')]),
          ],
        ),
        options: options,
      )
      .toList();
  return payload;
}

void main() {
  test('maps reasoningEffort to generationConfig.thinkingConfig', () async {
    final payload = await _capture(
        const AiRequestOptions(reasoningEffort: ReasoningEffort.medium));
    final genConfig =
        (payload['generationConfig'] as Map).cast<String, Object?>();
    final thinking =
        (genConfig['thinkingConfig'] as Map).cast<String, Object?>();
    expect(thinking['thinkingBudget'], ReasoningEffort.medium.budgetTokens);
  });

  test('omits thinkingConfig when reasoningEffort is unset', () async {
    final payload = await _capture(const AiRequestOptions(temperature: 0.5));
    final genConfig =
        (payload['generationConfig'] as Map?)?.cast<String, Object?>();
    expect(genConfig?.containsKey('thinkingConfig') ?? false, isFalse);
  });
}

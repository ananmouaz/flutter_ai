import 'dart:convert';

import 'package:flutter_ai_provider_anthropic/flutter_ai_provider_anthropic.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

Future<Map<String, Object?>> _capture(AiRequestOptions options) async {
  late Map<String, Object?> payload;
  final provider = AnthropicProvider(
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
  test('reasoningEffort enables adaptive thinking on 4.6+ (default model)',
      () async {
    // The default model (claude-opus-4-8) is adaptive-only: it rejects
    // budget_tokens, so we must emit {type: adaptive}.
    final payload = await _capture(
        const AiRequestOptions(reasoningEffort: ReasoningEffort.low));
    final thinking = (payload['thinking'] as Map).cast<String, Object?>();
    expect(thinking['type'], 'adaptive');
    expect(thinking.containsKey('budget_tokens'), isFalse);
  });

  test('reasoningEffort uses the budgeted shape on legacy models', () async {
    final payload = await _capture(const AiRequestOptions(
      model: 'claude-3-7-sonnet-latest',
      reasoningEffort: ReasoningEffort.low,
    ));
    final thinking = (payload['thinking'] as Map).cast<String, Object?>();
    expect(thinking['type'], 'enabled');
    expect(thinking['budget_tokens'], ReasoningEffort.low.budgetTokens);
  });

  test('raises max_tokens above the budget on legacy models', () async {
    // high budget (24576) exceeds the default max_tokens (4096); only the
    // budgeted shape needs the bump.
    final payload = await _capture(const AiRequestOptions(
      model: 'claude-sonnet-4-5',
      reasoningEffort: ReasoningEffort.high,
    ));
    expect(payload['max_tokens'] as int,
        greaterThan(ReasoningEffort.high.budgetTokens));
  });

  test('drops temperature when thinking is enabled', () async {
    final payload = await _capture(const AiRequestOptions(
      reasoningEffort: ReasoningEffort.medium,
      temperature: 0.7,
    ));
    expect(payload.containsKey('temperature'), isFalse);
    expect(payload.containsKey('thinking'), isTrue);
  });

  test('drops thinking when a responseFormat is set (forced tool choice)',
      () async {
    final payload = await _capture(const AiRequestOptions(
      reasoningEffort: ReasoningEffort.high,
      responseFormat: AiResponseFormat(
        name: 'result',
        schema: {'type': 'object'},
      ),
    ));
    // Forced tool_choice + thinking is a 400; structured output wins.
    expect(payload.containsKey('thinking'), isFalse);
    expect((payload['tool_choice'] as Map)['type'], 'tool');
  });

  test('an explicit thinking block in extra takes precedence', () async {
    final payload = await _capture(const AiRequestOptions(
      reasoningEffort: ReasoningEffort.high,
      extra: {
        'thinking': {'type': 'enabled', 'budget_tokens': 5000},
      },
    ));
    final thinking = (payload['thinking'] as Map).cast<String, Object?>();
    expect(thinking['budget_tokens'], 5000);
  });
}

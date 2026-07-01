import 'dart:convert';

import 'package:flutter_ai_provider_openai/flutter_ai_provider_openai.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

Future<Map<String, Object?>> _capture(AiRequestOptions options) async {
  late Map<String, Object?> payload;
  final provider = OpenAiProvider(
    apiKey: 'secret',
    client: MockClient.streaming((request, bodyStream) async {
      payload = (jsonDecode(await bodyStream.bytesToString()) as Map)
          .cast<String, Object?>();
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode('data: [DONE]\n')),
        200,
      );
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
  test('maps reasoningEffort to reasoning_effort', () async {
    final payload =
        await _capture(const AiRequestOptions(reasoningEffort: ReasoningEffort.high));
    expect(payload['reasoning_effort'], 'high');
  });

  test('omits reasoning_effort when unset', () async {
    final payload = await _capture(const AiRequestOptions());
    expect(payload.containsKey('reasoning_effort'), isFalse);
  });

  test('an explicit reasoning_effort in extra takes precedence', () async {
    final payload = await _capture(const AiRequestOptions(
      reasoningEffort: ReasoningEffort.high,
      extra: {'reasoning_effort': 'minimal'},
    ));
    expect(payload['reasoning_effort'], 'minimal');
  });
}

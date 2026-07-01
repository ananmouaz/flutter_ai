import 'package:flutter_ai_provider_anthropic/src/default_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('createDefaultHttpClient returns a usable client on this platform', () {
    final client = createDefaultHttpClient();
    addTearDown(client.close);
    expect(client, isA<http.Client>());
  });
}

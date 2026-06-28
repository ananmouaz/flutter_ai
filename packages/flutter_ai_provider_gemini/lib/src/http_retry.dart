import 'package:http/http.dart' as http;

/// Sends [build]'s request, retrying transient failures (network errors, HTTP
/// 429, and 5xx) up to [maxRetries] times with exponential backoff that honors
/// a `Retry-After` header. A fresh request is built per attempt.
///
/// Returns the `200` streamed response. Retries only happen *before* the body
/// is consumed — once a 200 stream starts, the caller owns it. Throws the
/// underlying error on a network failure, or a descriptive [Exception]
/// ("[label] request failed (status): body") on a non-retryable HTTP error;
/// callers surface these as a `StreamErrorEvent`.
Future<http.StreamedResponse> connectWithRetry({
  required http.Client client,
  required http.Request Function() build,
  required int maxRetries,
  required String label,
}) async {
  for (var attempt = 0;; attempt++) {
    final http.StreamedResponse response;
    try {
      response = await client.send(build());
    } on Object {
      if (attempt < maxRetries) {
        await Future<void>.delayed(_backoff(attempt));
        continue;
      }
      rethrow;
    }

    if (response.statusCode == 200) return response;

    if (_isRetryable(response.statusCode) && attempt < maxRetries) {
      final wait =
          _retryAfter(response.headers['retry-after']) ?? _backoff(attempt);
      await response.stream.drain<void>();
      await Future<void>.delayed(wait);
      continue;
    }

    final body = await response.stream.bytesToString();
    throw Exception('$label request failed (${response.statusCode}): $body');
  }
}

bool _isRetryable(int code) => code == 429 || (code >= 500 && code < 600);

Duration _backoff(int attempt) => Duration(milliseconds: 400 * (1 << attempt));

Duration? _retryAfter(String? header) {
  final seconds = int.tryParse(header?.trim() ?? '');
  return seconds == null ? null : Duration(seconds: seconds);
}

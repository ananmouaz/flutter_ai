import 'dart:async';
import 'dart:math';

import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:http/http.dart' as http;

/// Sends [build]'s request, retrying transient failures (network errors,
/// connect timeouts, HTTP 429, and 5xx) up to [maxRetries] times with
/// exponential backoff (capped and jittered) that honors a `Retry-After`
/// header. A fresh request is built per attempt.
///
/// Each `send` attempt is bounded by [timeout]; a connect timeout is treated as
/// a transient failure and retried like a network error.
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
  required Duration timeout,
}) async {
  for (var attempt = 0;; attempt++) {
    final http.StreamedResponse response;
    try {
      response = await client.send(build()).timeout(timeout);
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
    throw llmExceptionFor(
      response.statusCode,
      '$label: $body',
      retryAfter: _retryAfter(response.headers['retry-after']),
    );
  }
}

bool _isRetryable(int code) =>
    code == 408 || code == 409 || code == 429 || (code >= 500 && code < 600);

final _random = Random();

/// Exponential backoff, capped at 30s, with randomized jitter so retries from
/// many clients don't synchronize. The base doubles per attempt up to the cap,
/// then a random 0–100% jitter of the (capped) base is added on top.
Duration _backoff(int attempt) {
  const base = Duration(milliseconds: 400);
  const cap = Duration(seconds: 30);
  // Guard against overflow on large attempt counts before comparing to the cap.
  final shift = attempt.clamp(0, 30);
  final scaledMs = base.inMilliseconds * (1 << shift);
  final cappedMs = min(cap.inMilliseconds, scaledMs);
  final jitterMs = _random.nextInt(cappedMs + 1);
  return Duration(milliseconds: cappedMs + jitterMs);
}

Duration? _retryAfter(String? header) {
  final seconds = int.tryParse(header?.trim() ?? '');
  return seconds == null ? null : Duration(seconds: seconds);
}

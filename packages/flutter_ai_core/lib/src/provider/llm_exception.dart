/// A failed provider HTTP request, surfaced on
/// [StreamErrorEvent.error](../streaming/ai_stream_event.dart) so hosts can
/// branch on the *type* (auth vs. rate-limit vs. server) instead of
/// string-matching a message.
sealed class LlmException implements Exception {
  /// Creates a provider exception.
  const LlmException(this.statusCode, this.body, {this.retryAfter});

  /// The HTTP status code.
  final int statusCode;

  /// The (truncated) response body, for diagnostics.
  final String body;

  /// The server-advised retry delay (from `Retry-After`), if any.
  final Duration? retryAfter;

  @override
  String toString() => '$runtimeType($statusCode): $body';
}

/// Authentication/authorization failure (HTTP 401/403) — usually a bad or
/// missing API key.
final class LlmAuthException extends LlmException {
  /// Creates an auth exception.
  const LlmAuthException(super.statusCode, super.body);
}

/// Rate limited (HTTP 429). Honor [retryAfter] before retrying.
final class LlmRateLimitException extends LlmException {
  /// Creates a rate-limit exception.
  const LlmRateLimitException(super.statusCode, super.body, {super.retryAfter});
}

/// Server-side failure (HTTP 5xx, incl. Anthropic 529 overloaded).
final class LlmServerException extends LlmException {
  /// Creates a server exception.
  const LlmServerException(super.statusCode, super.body, {super.retryAfter});
}

/// A non-retryable client error (other 4xx) — e.g. a malformed request.
final class LlmRequestException extends LlmException {
  /// Creates a request exception.
  const LlmRequestException(super.statusCode, super.body);
}

/// Maps an HTTP [status] to the matching [LlmException] subtype.
LlmException llmExceptionFor(int status, String body, {Duration? retryAfter}) {
  if (status == 401 || status == 403) return LlmAuthException(status, body);
  if (status == 429) {
    return LlmRateLimitException(status, body, retryAfter: retryAfter);
  }
  if (status >= 500) {
    return LlmServerException(status, body, retryAfter: retryAfter);
  }
  return LlmRequestException(status, body);
}

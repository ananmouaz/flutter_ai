/// Why the model stopped generating a message.
///
/// Surfaced on the terminal stream event so the UI can react (for example,
/// announcing the final text to assistive technologies once generation is
/// complete).
enum FinishReason {
  /// The model emitted a natural stopping point or a stop sequence.
  stop('stop'),

  /// Generation was truncated by the maximum output token limit.
  length('length'),

  /// The model paused to call one or more tools.
  toolCalls('tool-calls'),

  /// Output was withheld or truncated by a content filter.
  contentFilter('content-filter'),

  /// Generation ended because of an error.
  error('error');

  const FinishReason(this.wireName);

  /// The stable string used on the wire and in JSON.
  final String wireName;

  /// Parses a [wireName] into its [FinishReason].
  ///
  /// Throws a [FormatException] if [value] is not a known reason.
  static FinishReason fromJson(String value) {
    for (final reason in values) {
      if (reason.wireName == value) return reason;
    }
    throw FormatException('Unknown FinishReason: "$value"');
  }

  /// The wire representation of this reason.
  String toJson() => wireName;
}

import 'package:flutter_ai_core/src/internal/equality.dart';

/// Provider-neutral knobs for a generation request.
///
/// Common parameters are first-class; anything provider-specific rides in
/// [extra], which a concrete provider passes through to its backend. Switching
/// models is as simple as constructing options with a different [model].
final class AiRequestOptions {
  /// Creates request options.
  const AiRequestOptions({
    this.model,
    this.temperature,
    this.maxOutputTokens,
    this.extra = const {},
  });

  /// The model identifier, e.g. `gpt-4o` or `gemini-2.0-flash`.
  final String? model;

  /// Sampling temperature, typically in the range `0.0`–`2.0`.
  final double? temperature;

  /// An upper bound on the number of tokens to generate.
  final int? maxOutputTokens;

  /// Provider-specific parameters passed through verbatim.
  final Map<String, Object?> extra;

  /// Returns a copy with the given fields replaced.
  AiRequestOptions copyWith({
    String? model,
    double? temperature,
    int? maxOutputTokens,
    Map<String, Object?>? extra,
  }) =>
      AiRequestOptions(
        model: model ?? this.model,
        temperature: temperature ?? this.temperature,
        maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
        extra: extra ?? this.extra,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiRequestOptions &&
          other.model == model &&
          other.temperature == temperature &&
          other.maxOutputTokens == maxOutputTokens &&
          deepEquals(other.extra, extra));

  @override
  int get hashCode =>
      Object.hash(model, temperature, maxOutputTokens, deepHash(extra));

  @override
  String toString() =>
      'AiRequestOptions(model: $model, temperature: $temperature, '
      'maxOutputTokens: $maxOutputTokens)';
}

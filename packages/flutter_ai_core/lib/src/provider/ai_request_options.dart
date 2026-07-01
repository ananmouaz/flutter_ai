import 'package:flutter_ai_core/src/internal/equality.dart';
import 'package:flutter_ai_core/src/provider/ai_response_format.dart';

/// How much effort a reasoning-capable model should spend on internal thinking
/// before answering.
///
/// A provider-neutral knob. Providers that expose an effort setting map it
/// directly (OpenAI `reasoning_effort`); providers that use a token budget map
/// it through [budgetTokens] (Anthropic `thinking.budget_tokens`, Gemini
/// `thinkingConfig.thinkingBudget`). Providers that don't support it ignore it.
enum ReasoningEffort {
  /// The least thinking the model/provider allows.
  minimal,

  /// Light reasoning.
  low,

  /// Moderate reasoning.
  medium,

  /// Deep reasoning.
  high;

  /// A canonical thinking-token budget for providers that take one instead of
  /// an effort level. A documented heuristic — pass an exact budget via
  /// [AiRequestOptions.extra] when you need provider-specific precision.
  int get budgetTokens => switch (this) {
        ReasoningEffort.minimal => 1024,
        ReasoningEffort.low => 2048,
        ReasoningEffort.medium => 8192,
        ReasoningEffort.high => 24576,
      };

  /// The wire value OpenAI's `reasoning_effort` expects.
  String get openAiValue => name;
}

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
    this.responseFormat,
    this.reasoningEffort,
    this.cachePrompt = false,
    this.extra = const {},
  });

  /// The model identifier, e.g. `gpt-4o` or `gemini-2.0-flash`.
  final String? model;

  /// Sampling temperature, typically in the range `0.0`–`2.0`.
  final double? temperature;

  /// An upper bound on the number of tokens to generate.
  final int? maxOutputTokens;

  /// When set, requests structured output constrained to a JSON schema. See
  /// [AiResponseFormat].
  final AiResponseFormat? responseFormat;

  /// How hard a reasoning-capable model should think before answering. Maps to
  /// each provider's native control (OpenAI `reasoning_effort`, Anthropic
  /// `thinking.budget_tokens`, Gemini `thinkingConfig.thinkingBudget`) and is
  /// ignored by providers that don't support it. An explicit value in [extra]
  /// takes precedence. See [ReasoningEffort].
  final ReasoningEffort? reasoningEffort;

  /// Hints that the stable prompt prefix (system instructions + tools) should be
  /// cached to cut cost and latency on repeated context.
  ///
  /// Anthropic applies explicit `cache_control` markers; OpenAI and Gemini cache
  /// automatically, so this is a no-op there. Off by default.
  final bool cachePrompt;

  /// Provider-specific parameters passed through verbatim.
  final Map<String, Object?> extra;

  /// Returns a copy with the given fields replaced.
  AiRequestOptions copyWith({
    String? model,
    double? temperature,
    int? maxOutputTokens,
    AiResponseFormat? responseFormat,
    ReasoningEffort? reasoningEffort,
    bool? cachePrompt,
    Map<String, Object?>? extra,
  }) =>
      AiRequestOptions(
        model: model ?? this.model,
        temperature: temperature ?? this.temperature,
        maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
        responseFormat: responseFormat ?? this.responseFormat,
        reasoningEffort: reasoningEffort ?? this.reasoningEffort,
        cachePrompt: cachePrompt ?? this.cachePrompt,
        extra: extra ?? this.extra,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiRequestOptions &&
          other.model == model &&
          other.temperature == temperature &&
          other.maxOutputTokens == maxOutputTokens &&
          other.responseFormat == responseFormat &&
          other.reasoningEffort == reasoningEffort &&
          other.cachePrompt == cachePrompt &&
          deepEquals(other.extra, extra));

  @override
  int get hashCode => Object.hash(
        model,
        temperature,
        maxOutputTokens,
        responseFormat,
        reasoningEffort,
        cachePrompt,
        deepHash(extra),
      );

  @override
  String toString() =>
      'AiRequestOptions(model: $model, temperature: $temperature, '
      'maxOutputTokens: $maxOutputTokens)';
}

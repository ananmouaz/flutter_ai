/// Token usage for a model turn, with an optional cost estimate.
///
/// Every field is nullable because providers report different subsets (and some
/// only at the end of a stream). [cachedInputTokens] is the portion of
/// [inputTokens] served from a prompt cache; [cacheCreationTokens] is the
/// portion of [inputTokens] written to a prompt cache (billed at a premium);
/// [reasoningTokens] is the portion of [outputTokens] spent on extended
/// thinking.
final class AiUsage {
  /// Creates a usage record.
  const AiUsage({
    this.inputTokens,
    this.outputTokens,
    this.cachedInputTokens,
    this.cacheCreationTokens,
    this.reasoningTokens,
    this.totalTokens,
  });

  /// Reconstructs usage from [json].
  factory AiUsage.fromJson(Map<String, Object?> json) => AiUsage(
        inputTokens: json['inputTokens'] as int?,
        outputTokens: json['outputTokens'] as int?,
        cachedInputTokens: json['cachedInputTokens'] as int?,
        cacheCreationTokens: json['cacheCreationTokens'] as int?,
        reasoningTokens: json['reasoningTokens'] as int?,
        totalTokens: json['totalTokens'] as int?,
      );

  /// Prompt tokens billed at the input rate (includes [cachedInputTokens]).
  final int? inputTokens;

  /// Generated tokens billed at the output rate (includes [reasoningTokens]).
  final int? outputTokens;

  /// Portion of [inputTokens] served from a prompt cache (cheaper).
  final int? cachedInputTokens;

  /// Portion of [inputTokens] written to a prompt cache. Providers (e.g.
  /// Anthropic) bill these at a premium over the base input rate (~1.25x).
  final int? cacheCreationTokens;

  /// Portion of [outputTokens] spent on extended thinking.
  final int? reasoningTokens;

  /// Total tokens, if the provider reports it directly. Otherwise derive it via
  /// [resolvedTotal].
  final int? totalTokens;

  /// [totalTokens] if present, else `inputTokens + outputTokens` when both are
  /// known, else `null`.
  int? get resolvedTotal {
    if (totalTokens != null) return totalTokens;
    if (inputTokens == null && outputTokens == null) return null;
    return (inputTokens ?? 0) + (outputTokens ?? 0);
  }

  /// Merges two partial usages, summing each field. Useful for accumulating
  /// across streamed events or summing a whole session.
  AiUsage operator +(AiUsage other) => AiUsage(
        inputTokens: _add(inputTokens, other.inputTokens),
        outputTokens: _add(outputTokens, other.outputTokens),
        cachedInputTokens: _add(cachedInputTokens, other.cachedInputTokens),
        cacheCreationTokens:
            _add(cacheCreationTokens, other.cacheCreationTokens),
        reasoningTokens: _add(reasoningTokens, other.reasoningTokens),
        totalTokens: _add(totalTokens, other.totalTokens),
      );

  /// Estimates cost given per-million-token prices (typically USD). Returns
  /// `null` when neither token count is known.
  ///
  /// [cachedInputTokens] and [cacheCreationTokens] are subsets of
  /// [inputTokens]; they are subtracted out and billed separately so they are
  /// never double-counted at the base rate. The remaining uncached, non-cache-
  /// write input is billed at [inputPer1M]; cache reads at [cachedInputPer1M]
  /// when given (else [inputPer1M]); cache writes at [cacheWritePer1M] when
  /// given (else `1.25 * inputPer1M`, the Anthropic convention); all output
  /// (including reasoning) at [outputPer1M].
  double? estimateCost({
    required double inputPer1M,
    required double outputPer1M,
    double? cachedInputPer1M,
    double? cacheWritePer1M,
  }) {
    if (inputTokens == null && outputTokens == null) return null;
    final cached = cachedInputTokens ?? 0;
    final cacheWrite = cacheCreationTokens ?? 0;
    final uncachedInput = (inputTokens ?? 0) - cached - cacheWrite;
    final inputCost = uncachedInput * inputPer1M / 1e6 +
        cached * (cachedInputPer1M ?? inputPer1M) / 1e6 +
        cacheWrite * (cacheWritePer1M ?? inputPer1M * 1.25) / 1e6;
    final outputCost = (outputTokens ?? 0) * outputPer1M / 1e6;
    return inputCost + outputCost;
  }

  /// Serializes this usage, omitting null fields.
  Map<String, Object?> toJson() => {
        if (inputTokens != null) 'inputTokens': inputTokens,
        if (outputTokens != null) 'outputTokens': outputTokens,
        if (cachedInputTokens != null) 'cachedInputTokens': cachedInputTokens,
        if (cacheCreationTokens != null)
          'cacheCreationTokens': cacheCreationTokens,
        if (reasoningTokens != null) 'reasoningTokens': reasoningTokens,
        if (totalTokens != null) 'totalTokens': totalTokens,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiUsage &&
          other.inputTokens == inputTokens &&
          other.outputTokens == outputTokens &&
          other.cachedInputTokens == cachedInputTokens &&
          other.cacheCreationTokens == cacheCreationTokens &&
          other.reasoningTokens == reasoningTokens &&
          other.totalTokens == totalTokens);

  @override
  int get hashCode => Object.hash(
        inputTokens,
        outputTokens,
        cachedInputTokens,
        cacheCreationTokens,
        reasoningTokens,
        totalTokens,
      );

  @override
  String toString() => 'AiUsage(in: $inputTokens, out: $outputTokens, cached: '
      '$cachedInputTokens, cacheWrite: $cacheCreationTokens, reasoning: '
      '$reasoningTokens, total: $resolvedTotal)';

  static int? _add(int? a, int? b) =>
      (a == null && b == null) ? null : (a ?? 0) + (b ?? 0);
}

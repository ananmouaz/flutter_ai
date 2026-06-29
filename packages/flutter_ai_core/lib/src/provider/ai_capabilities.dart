import 'package:flutter_ai_core/src/internal/equality.dart';
import 'package:flutter_ai_core/src/models/ai_conversation.dart';
import 'package:flutter_ai_core/src/models/tool_definition.dart';
import 'package:flutter_ai_core/src/provider/ai_request_options.dart';
import 'package:flutter_ai_core/src/provider/llm_provider.dart';

/// A single embedding vector produced by an [EmbeddingProvider].
///
/// [values] is the dense vector for one input string; [index] is that input's
/// position in the batch passed to [EmbeddingProvider.embed], so callers can
/// re-associate vectors with their source text when a provider returns them out
/// of order (or simply confirm alignment).
final class AiEmbedding {
  /// Creates an embedding holding [values] at batch position [index].
  const AiEmbedding(this.values, {this.index});

  /// The dense embedding vector.
  final List<double> values;

  /// The position of the source input in the request batch, if reported.
  final int? index;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiEmbedding &&
          other.index == index &&
          deepEquals(other.values, values));

  @override
  int get hashCode => Object.hash(index, deepHash(values));

  @override
  String toString() => 'AiEmbedding(${values.length} dims, index: $index)';
}

/// An **optional** capability a provider MAY implement to turn text into
/// embedding vectors (for semantic search, clustering, and RAG retrieval).
///
/// This is an opt-in mixin interface, separate from [LlmProvider]: a backend
/// that supports embeddings implements it in addition to (or instead of)
/// generation. Check support at runtime with `provider is EmbeddingProvider`
/// before calling [embed]; providers without an embeddings endpoint simply do
/// not implement it.
abstract interface class EmbeddingProvider {
  /// Embeds each string in [inputs], returning one [AiEmbedding] per input.
  ///
  /// [model] selects the embedding model; when `null` the implementation uses
  /// its own default. The returned list aligns with [inputs] by
  /// [AiEmbedding.index] (and typically by position).
  Future<List<AiEmbedding>> embed(List<String> inputs, {String? model});
}

/// An **optional** capability a provider MAY implement to count the tokens a
/// request would consume *before* sending it.
///
/// Useful for pre-flight budget checks, context-window guards, and cost
/// estimates. Like [EmbeddingProvider] this is an opt-in mixin interface:
/// check support at runtime with `provider is TokenCounter`. Providers without
/// a token-count endpoint simply do not implement it.
abstract interface class TokenCounter {
  /// Returns the number of tokens [conversation] (plus any [tools] and
  /// [options]) would occupy in a generation request.
  Future<int> countTokens(
    AiConversation conversation, {
    List<ToolDefinition> tools,
    AiRequestOptions? options,
  });
}

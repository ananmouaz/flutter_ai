import 'dart:convert';

import 'package:flutter_ai_core/src/internal/equality.dart';
import 'package:flutter_ai_core/src/models/ai_conversation.dart';
import 'package:flutter_ai_core/src/models/tool_definition.dart';
import 'package:flutter_ai_core/src/provider/ai_request_options.dart';
import 'package:flutter_ai_core/src/provider/ai_response_format.dart';
import 'package:flutter_ai_core/src/provider/llm_provider.dart';
import 'package:flutter_ai_core/src/streaming/ai_stream_event.dart';
import 'package:flutter_ai_core/src/streaming/json_accumulator.dart';

/// Structured-output helpers layered on top of any [LlmProvider].
///
/// These build on the existing streaming contract: they send the conversation
/// with [AiRequestOptions.responseFormat] set to the requested
/// [AiResponseFormat], collect the assistant's streamed text (which is the JSON
/// object), and surface it as a decoded `Map`. No provider changes are needed —
/// every backend that honors `responseFormat` gets typed objects for free.
extension GenerateObject on LlmProvider {
  /// Generates a single structured object constrained to [format].
  ///
  /// Sends [conversation] with [options] merged so its
  /// [AiRequestOptions.responseFormat] is [format], collects the streamed
  /// assistant text, and JSON-decodes it to a `Map`.
  ///
  /// Throws a [FormatException] (carrying the raw text) if the response is not a
  /// JSON object. Soft schema issues do not throw — the decoded object is
  /// returned as-is.
  Future<Map<String, Object?>> generateObject(
    AiConversation conversation, {
    required AiResponseFormat format,
    List<ToolDefinition> tools = const [],
    AiRequestOptions? options,
  }) async {
    final buffer = StringBuffer();
    await for (final event in send(
      conversation,
      tools: tools,
      options: _withFormat(options, format),
    )) {
      switch (event) {
        case TextDelta(:final delta):
          buffer.write(delta);
        case StreamErrorEvent(:final error):
          throw FormatException('generateObject failed: $error');
        case _:
          break;
      }
    }

    final raw = buffer.toString();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw FormatException(
        'generateObject: response was not valid JSON (${e.message})',
        raw,
      );
    }
    if (decoded is! Map) {
      throw FormatException(
        'generateObject: expected a JSON object but got '
        '${decoded.runtimeType}',
        raw,
      );
    }
    return decoded.cast<String, Object?>();
  }

  /// Generates a structured object, yielding the evolving partial object as it
  /// streams.
  ///
  /// Sends the same request as [generateObject] but feeds each [TextDelta] into
  /// a [JsonAccumulator] and yields the best complete-prefix `Map` whenever it
  /// advances, ending with the final complete object. Because [JsonAccumulator]
  /// only ever surfaces a valid prefix of the document, intermediate yields are
  /// growing prefixes of the final object.
  Stream<Map<String, Object?>> streamObject(
    AiConversation conversation, {
    required AiResponseFormat format,
    List<ToolDefinition> tools = const [],
    AiRequestOptions? options,
  }) async* {
    final accumulator = JsonAccumulator();
    Map<String, Object?>? last;

    await for (final event in send(
      conversation,
      tools: tools,
      options: _withFormat(options, format),
    )) {
      switch (event) {
        case TextDelta(:final delta):
          accumulator.add(delta);
          final partial = accumulator.parsePartial();
          if (partial is Map) {
            final next = partial.cast<String, Object?>();
            // Only yield when the value actually advanced, so identical
            // re-parses between deltas don't emit duplicate frames.
            if (last == null || !deepEquals(last, next)) {
              last = next;
              yield next;
            }
          }
        case StreamErrorEvent(:final error):
          throw FormatException('streamObject failed: $error');
        case _:
          break;
      }
    }

    // Surface the final, strictly-parsed object if it differs from the last
    // partial (e.g. a trailing token only completed at the end).
    final complete = accumulator.tryParseComplete();
    if (complete is Map) {
      final next = complete.cast<String, Object?>();
      if (last == null || !deepEquals(last, next)) {
        yield next;
      }
    }
  }

  AiRequestOptions _withFormat(
    AiRequestOptions? options,
    AiResponseFormat format,
  ) =>
      (options ?? const AiRequestOptions()).copyWith(responseFormat: format);
}

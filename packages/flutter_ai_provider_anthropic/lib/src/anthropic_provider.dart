import 'dart:async';
import 'dart:convert';

import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_provider_anthropic/src/anthropic_event_parser.dart';
import 'package:flutter_ai_provider_anthropic/src/http_retry.dart';
import 'package:http/http.dart' as http;

/// An `LlmProvider` backed by the Anthropic **Messages API**
/// (`POST /v1/messages`).
///
/// Streams text, extended-thinking, tool calls, and finish reasons as
/// `AiStreamEvent`s. The HTTP client is injectable for testing and custom
/// transport configuration.
///
/// Notes:
///  * `max_tokens` is required by the API; [defaultMaxTokens] is used when
///    [AiRequestOptions.maxOutputTokens] is not set.
///  * System messages are folded into the top-level `system` field (Anthropic
///    has no `system` role inside `messages`).
///  * Assistant tool calls and tool results are mapped to Anthropic
///    `tool_use` / `tool_result` content blocks.
///  * `temperature` is forwarded only when set; newer Claude models reject
///    sampling parameters, so leave it unset for those.
///  * To enable extended thinking, pass it through [AiRequestOptions.extra],
///    e.g. `{'thinking': {'type': 'adaptive'}}`.
///
/// > The request/response mapping is unit-tested against recorded SSE events;
/// > supply an API key to use it against the live API.
class AnthropicProvider implements LlmProvider {
  /// Creates a provider.
  ///
  /// [apiKey] authenticates requests (sent as `x-api-key`). [baseUrl] defaults
  /// to the public Anthropic v1 endpoint; override it for a proxy or gateway.
  /// [client] is injectable (defaults to a new [http.Client]). [defaultModel]
  /// and [defaultMaxTokens] are used when [AiRequestOptions] omits them.
  /// [timeout] bounds both the initial connection and the idle gap between
  /// streamed chunks.
  AnthropicProvider({
    required this.apiKey,
    Uri? baseUrl,
    http.Client? client,
    this.defaultModel = 'claude-opus-4-8',
    this.defaultMaxTokens = 4096,
    this.anthropicVersion = '2023-06-01',
    this.maxRetries = 2,
    this.timeout = const Duration(seconds: 60),
  })  : _baseUrl = baseUrl ?? Uri.parse('https://api.anthropic.com/v1'),
        _ownsClient = client == null,
        _client = client ?? http.Client();

  /// The API key sent as the `x-api-key` header.
  final String apiKey;

  /// The default model when options don't specify one.
  final String defaultModel;

  /// The `max_tokens` used when options don't specify one (the API requires it).
  final int defaultMaxTokens;

  /// The `anthropic-version` header value.
  final String anthropicVersion;

  /// How many times to retry the initial connection on a transient failure
  /// (network error, 429, or 5xx), with backoff honoring `Retry-After`.
  final int maxRetries;

  /// Bounds the initial connection (a connect timeout is retried like a network
  /// error) and the idle gap between streamed chunks (a mid-stream stall yields
  /// a terminal error instead of hanging forever).
  final Duration timeout;

  final Uri _baseUrl;
  final http.Client _client;

  /// Whether this provider created [_client] itself (vs. an injected one).
  /// [close] only closes a client it owns.
  final bool _ownsClient;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    final (system, messages) = _buildMessages(conversation);
    final responseFormat = options?.responseFormat;
    // Anthropic has no response_format; structured output is a forced tool whose
    // input is the schema (the parser surfaces its input as the JSON answer).
    final toolList = <Map<String, Object?>>[
      if (tools != null) ..._buildTools(tools),
      if (responseFormat != null)
        {
          'name': responseFormat.name,
          'description': 'Respond with the structured result.',
          'input_schema': responseFormat.schema,
        },
    ];
    // Prompt caching: mark the stable prefix (system + the last tool, which
    // anchors the cached span covering all tools) with `cache_control`.
    final cache = options?.cachePrompt ?? false;
    const cacheControl = {'type': 'ephemeral'};
    if (cache && toolList.isNotEmpty) {
      toolList[toolList.length - 1] = {
        ...toolList.last,
        'cache_control': cacheControl,
      };
    }
    final payload = <String, Object?>{
      if (options?.extra != null) ...options!.extra,
      'model': options?.model ?? defaultModel,
      'max_tokens': options?.maxOutputTokens ?? defaultMaxTokens,
      'stream': true,
      'messages': messages,
      if (system != null && system.isNotEmpty)
        'system': cache
            ? [
                {
                  'type': 'text',
                  'text': system,
                  'cache_control': cacheControl,
                },
              ]
            : system,
      if (options?.temperature != null) 'temperature': options!.temperature,
      if (toolList.isNotEmpty) 'tools': toolList,
      if (responseFormat != null)
        'tool_choice': {'type': 'tool', 'name': responseFormat.name},
    };

    final http.StreamedResponse response;
    try {
      response = await connectWithRetry(
        client: _client,
        maxRetries: maxRetries,
        label: 'Anthropic',
        timeout: timeout,
        build: () => http.Request('POST', _endpoint())
          ..headers['x-api-key'] = apiKey
          ..headers['anthropic-version'] = anthropicVersion
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode(payload),
      );
    } on Object catch (error) {
      yield StreamErrorEvent(error: error);
      return;
    }

    final parser =
        AnthropicEventParser(structuredToolName: responseFormat?.name);
    // Idle timeout: a stall longer than [timeout] between chunks aborts the
    // `await for` with a TimeoutException instead of hanging forever.
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(timeout);
    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        // Anthropic SSE interleaves `event:` and `data:` lines; the JSON on the
        // `data:` line carries its own `type`, so we only need the data lines.
        if (!trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data.isEmpty) continue;
        try {
          final Map<String, Object?> chunk;
          try {
            chunk = (jsonDecode(data) as Map).cast<String, Object?>();
          } on FormatException {
            continue; // skip malformed keep-alive or partial lines
          }
          for (final event in parser.parse(chunk)) {
            yield event;
          }
        } on Object catch (error) {
          // A valid-JSON-but-wrong-shape chunk must not kill the whole stream;
          // surface it as a StreamErrorEvent and skip the bad chunk.
          yield StreamErrorEvent(error: error);
          continue;
        }
      }
    } on TimeoutException catch (error) {
      // A mid-stream stall: mark the in-flight message errored. Don't also
      // finalize() — that terminal MessageFinished would mask the timeout.
      yield StreamErrorEvent(error: error, messageId: parser.messageId);
      return;
    }
    // Stream ended — emit a terminal event if no `message_stop` arrived.
    for (final event in parser.finalize()) {
      yield event;
    }
  }

  /// Closes the underlying HTTP client, but only if this provider created it.
  /// When a `client` was injected, `close` is a no-op so a shared client isn't
  /// torn out from under its owner.
  void close() {
    if (_ownsClient) _client.close();
  }

  Uri _endpoint() {
    final base = _baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/messages');
  }

  /// Builds the top-level `system` string and the `messages` array. Messages
  /// with empty content are dropped (the API rejects them).
  (String?, List<Map<String, Object?>>) _buildMessages(
    AiConversation conversation,
  ) {
    final systemBuffer = StringBuffer();
    final messages = <Map<String, Object?>>[];

    void addContent(String role, List<Map<String, Object?>> content) {
      if (content.isEmpty) return;
      messages.add({'role': role, 'content': content});
    }

    for (final message in conversation.messages) {
      switch (message.role) {
        case AiRole.system:
          if (message.text.isEmpty) break;
          if (systemBuffer.isNotEmpty) systemBuffer.write('\n\n');
          systemBuffer.write(message.text);
        case AiRole.user:
          addContent('user', [
            if (message.text.isNotEmpty) {'type': 'text', 'text': message.text},
            for (final image in _images(message))
              {'type': 'image', 'source': _imageSource(image)},
          ]);
        case AiRole.assistant:
          addContent('assistant', [
            if (message.text.isNotEmpty) {'type': 'text', 'text': message.text},
            for (final call in message.parts.whereType<ToolCallPart>())
              {
                'type': 'tool_use',
                'id': call.toolCallId,
                'name': call.toolName,
                'input': call.args,
              },
          ]);
        case AiRole.tool:
          addContent('user', [
            for (final result in message.parts.whereType<ToolResultPart>())
              {
                'type': 'tool_result',
                'tool_use_id': result.toolCallId,
                'content': result.result is String
                    ? result.result as String
                    : jsonEncode(result.result),
                if (result.isError) 'is_error': true,
              },
          ]);
      }
    }

    final system = systemBuffer.isEmpty ? null : systemBuffer.toString();
    return (system, _mergeAdjacentRoles(messages));
  }

  /// Anthropic requires strict user/assistant alternation; consecutive entries
  /// with the same `role` (e.g. a tool-result `user` turn following a normal
  /// `user` turn, or two tool turns in a row) 400 with "roles must alternate".
  /// Merge adjacent same-role messages by concatenating their `content` arrays.
  static List<Map<String, Object?>> _mergeAdjacentRoles(
    List<Map<String, Object?>> messages,
  ) {
    final merged = <Map<String, Object?>>[];
    for (final message in messages) {
      if (merged.isNotEmpty && merged.last['role'] == message['role']) {
        final content = [
          ...(merged.last['content']! as List),
          ...(message['content']! as List),
        ];
        merged.last['content'] = content;
      } else {
        merged.add({...message});
      }
    }
    return merged;
  }

  static Iterable<FilePart> _images(AiMessage message) => message.parts
      .whereType<FilePart>()
      .where((f) => f.mediaType.startsWith('image/'));

  /// Anthropic image source: base64 for inline bytes, else a URL source.
  static Map<String, Object?> _imageSource(FilePart image) =>
      image.bytes != null
          ? {
              'type': 'base64',
              'media_type': image.mediaType,
              'data': base64Encode(image.bytes!),
            }
          : {'type': 'url', 'url': image.url.toString()};

  List<Map<String, Object?>> _buildTools(List<ToolDefinition> tools) => [
        for (final tool in tools)
          {
            'name': tool.name,
            'description': tool.description,
            'input_schema': tool.parametersSchema,
          },
      ];
}

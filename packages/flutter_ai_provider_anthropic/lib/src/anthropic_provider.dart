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
  AnthropicProvider({
    required this.apiKey,
    Uri? baseUrl,
    http.Client? client,
    this.defaultModel = 'claude-opus-4-8',
    this.defaultMaxTokens = 4096,
    this.anthropicVersion = '2023-06-01',
    this.maxRetries = 2,
  })  : _baseUrl = baseUrl ?? Uri.parse('https://api.anthropic.com/v1'),
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

  final Uri _baseUrl;
  final http.Client _client;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    final (system, messages) = _buildMessages(conversation);
    final payload = <String, Object?>{
      if (options?.extra != null) ...options!.extra,
      'model': options?.model ?? defaultModel,
      'max_tokens': options?.maxOutputTokens ?? defaultMaxTokens,
      'stream': true,
      'messages': messages,
      if (system != null && system.isNotEmpty) 'system': system,
      if (options?.temperature != null) 'temperature': options!.temperature,
      if (tools != null && tools.isNotEmpty) 'tools': _buildTools(tools),
    };

    final http.StreamedResponse response;
    try {
      response = await connectWithRetry(
        client: _client,
        maxRetries: maxRetries,
        label: 'Anthropic',
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

    final parser = AnthropicEventParser();
    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      final trimmed = line.trim();
      // Anthropic SSE interleaves `event:` and `data:` lines; the JSON on the
      // `data:` line carries its own `type`, so we only need the data lines.
      if (!trimmed.startsWith('data:')) continue;
      final data = trimmed.substring(5).trim();
      if (data.isEmpty) continue;
      final Map<String, Object?> chunk;
      try {
        chunk = (jsonDecode(data) as Map).cast<String, Object?>();
      } on FormatException {
        continue; // skip malformed keep-alive or partial lines
      }
      for (final event in parser.parse(chunk)) {
        yield event;
      }
    }
    // Stream ended — emit a terminal event if no `message_stop` arrived.
    for (final event in parser.finalize()) {
      yield event;
    }
  }

  /// Closes the underlying HTTP client. Call when the provider is discarded if
  /// it created its own client.
  void close() => _client.close();

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
    return (system, messages);
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

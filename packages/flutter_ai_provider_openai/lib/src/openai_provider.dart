import 'dart:convert';

import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_provider_openai/src/http_retry.dart';
import 'package:flutter_ai_provider_openai/src/openai_chunk_parser.dart';
import 'package:http/http.dart' as http;

/// An `LlmProvider` backed by the OpenAI Chat Completions API (or any
/// OpenAI-compatible endpoint, via a custom base URL).
///
/// Streams text, tool calls, and finish reasons as `AiStreamEvent`s. The HTTP
/// client is injectable for testing and for custom transport configuration.
///
/// > Note: the request/response mapping is unit-tested against recorded SSE
/// > chunks; point the base URL at a live endpoint and supply an API key to use
/// > it for real.
class OpenAiProvider implements LlmProvider {
  /// Creates a provider.
  ///
  /// [apiKey] authenticates requests. [baseUrl] defaults to the public OpenAI
  /// v1 endpoint; override it for Azure OpenAI, a proxy, or a compatible server.
  /// [client] is injectable (defaults to a new [http.Client]). [defaultModel] is
  /// used when [AiRequestOptions.model] is not set.
  OpenAiProvider({
    required this.apiKey,
    Uri? baseUrl,
    http.Client? client,
    this.defaultModel = 'gpt-4o-mini',
    this.maxRetries = 2,
  })  : _baseUrl = baseUrl ?? Uri.parse('https://api.openai.com/v1'),
        _client = client ?? http.Client();

  /// The API key sent as a bearer token.
  final String apiKey;

  /// The default model when options don't specify one.
  final String defaultModel;

  /// How many times to retry the initial connection on a transient failure
  /// (network error, 429, or 5xx), with exponential backoff that honors a
  /// `Retry-After` header. Retries happen before any events stream.
  final int maxRetries;

  final Uri _baseUrl;
  final http.Client _client;

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    final payload = <String, Object?>{
      if (options?.extra != null) ...options!.extra,
      'model': options?.model ?? defaultModel,
      'messages': _buildMessages(conversation),
      'stream': true,
      if (options?.temperature != null) 'temperature': options!.temperature,
      if (options?.maxOutputTokens != null)
        'max_tokens': options!.maxOutputTokens,
      if (tools != null && tools.isNotEmpty) 'tools': _buildTools(tools),
    };

    final http.StreamedResponse response;
    try {
      response = await connectWithRetry(
        client: _client,
        maxRetries: maxRetries,
        label: 'OpenAI',
        build: () => http.Request('POST', _endpoint())
          ..headers['authorization'] = 'Bearer $apiKey'
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode(payload),
      );
    } on Object catch (error) {
      yield StreamErrorEvent(error: error);
      return;
    }

    final parser = OpenAiChunkParser();
    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final data = trimmed.substring(5).trim();
      if (data == '[DONE]') break;
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
    // Stream ended — emit a terminal event if no finish_reason/[DONE] arrived.
    for (final event in parser.finalize()) {
      yield event;
    }
  }

  /// Closes the underlying HTTP client. Call when the provider is discarded if it
  /// created its own client.
  void close() => _client.close();

  Uri _endpoint() {
    final base = _baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/chat/completions');
  }

  List<Map<String, Object?>> _buildMessages(AiConversation conversation) {
    final messages = <Map<String, Object?>>[];
    for (final message in conversation.messages) {
      switch (message.role) {
        case AiRole.system:
          messages.add({'role': 'system', 'content': message.text});
        case AiRole.user:
          messages.add({'role': 'user', 'content': _userContent(message)});
        case AiRole.assistant:
          final toolCalls = message.parts.whereType<ToolCallPart>().toList();
          messages.add({
            'role': 'assistant',
            'content': message.text.isEmpty ? null : message.text,
            if (toolCalls.isNotEmpty)
              'tool_calls': [
                for (final call in toolCalls)
                  {
                    'id': call.toolCallId,
                    'type': 'function',
                    'function': {
                      'name': call.toolName,
                      'arguments': jsonEncode(call.args),
                    },
                  },
              ],
          });
          messages.addAll(_toolResults(message));
        case AiRole.tool:
          messages.addAll(_toolResults(message));
      }
    }
    return messages;
  }

  /// A user message's content: a plain string when text-only, or a content
  /// array with `image_url` parts when it carries image attachments.
  Object? _userContent(AiMessage message) {
    final images = message.parts
        .whereType<FilePart>()
        .where((f) => f.mediaType.startsWith('image/'))
        .toList();
    if (images.isEmpty) return message.text;
    return [
      if (message.text.isNotEmpty) {'type': 'text', 'text': message.text},
      for (final image in images)
        {
          'type': 'image_url',
          'image_url': {'url': _imageUrl(image)},
        },
    ];
  }

  /// A data: URI for inline bytes, else the remote URL.
  static String _imageUrl(FilePart image) => image.bytes != null
      ? 'data:${image.mediaType};base64,${base64Encode(image.bytes!)}'
      : image.url.toString();

  Iterable<Map<String, Object?>> _toolResults(AiMessage message) =>
      message.parts.whereType<ToolResultPart>().map(
            (result) => {
              'role': 'tool',
              'tool_call_id': result.toolCallId,
              'content': result.result is String
                  ? result.result as String
                  : jsonEncode(result.result),
            },
          );

  List<Map<String, Object?>> _buildTools(List<ToolDefinition> tools) => [
        for (final tool in tools)
          {
            'type': 'function',
            'function': {
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.parametersSchema,
            },
          },
      ];
}

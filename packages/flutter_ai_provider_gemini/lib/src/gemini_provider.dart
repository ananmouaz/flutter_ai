import 'dart:convert';

import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_provider_gemini/src/gemini_event_parser.dart';
import 'package:flutter_ai_provider_gemini/src/http_retry.dart';
import 'package:http/http.dart' as http;

/// An `LlmProvider` backed by the **native** Google Gemini API
/// (`models/{model}:streamGenerateContent?alt=sse`).
///
/// Unlike the OpenAI-compatible Gemini endpoint, this provider speaks Gemini's
/// own wire format, which unlocks **Google Search grounding** — set
/// [enableGrounding] (or pass a `googleSearch` tool via [AiRequestOptions.extra])
/// and grounded answers stream their web sources back as `SourcePart`s.
///
/// Streams text, thinking, function calls, grounding citations, and finish
/// reasons as `AiStreamEvent`s. The HTTP client is injectable for testing.
///
/// Notes:
///  * System messages are folded into `systemInstruction`.
///  * Assistant function calls map to `functionCall` parts; tool results map to
///    `functionResponse` parts (the function name is recovered from the matching
///    call earlier in the conversation).
///  * `temperature` / `maxOutputTokens` are sent under `generationConfig`.
///
/// > The request/response mapping is unit-tested against recorded SSE chunks;
/// > supply an API key to use it against the live API.
class GeminiProvider implements LlmProvider {
  /// Creates a provider.
  ///
  /// [apiKey] authenticates requests (sent as `x-goog-api-key`). [baseUrl]
  /// defaults to the public Generative Language v1beta endpoint. [client] is
  /// injectable. [defaultModel] is used when [AiRequestOptions.model] is unset.
  /// [enableGrounding] adds the Google Search tool to every request.
  GeminiProvider({
    required this.apiKey,
    Uri? baseUrl,
    http.Client? client,
    this.defaultModel = 'gemini-2.5-flash',
    this.enableGrounding = false,
    this.maxRetries = 2,
  })  : _baseUrl = baseUrl ??
            Uri.parse('https://generativelanguage.googleapis.com/v1beta'),
        _client = client ?? http.Client();

  /// The API key sent as the `x-goog-api-key` header.
  final String apiKey;

  /// The default model when options don't specify one.
  final String defaultModel;

  /// Whether to attach the Google Search grounding tool to every request.
  final bool enableGrounding;

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
    final (systemInstruction, contents) = _buildContents(conversation);
    final toolBlock = _buildTools(tools);

    final generationConfig = <String, Object?>{
      if (options?.temperature != null) 'temperature': options!.temperature,
      if (options?.maxOutputTokens != null)
        'maxOutputTokens': options!.maxOutputTokens,
    };

    final payload = <String, Object?>{
      if (options?.extra != null) ...options!.extra,
      'contents': contents,
      if (systemInstruction != null)
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
      if (toolBlock != null) 'tools': toolBlock,
      if (generationConfig.isNotEmpty) 'generationConfig': generationConfig,
    };

    final model = options?.model ?? defaultModel;
    final http.StreamedResponse response;
    try {
      response = await connectWithRetry(
        client: _client,
        maxRetries: maxRetries,
        label: 'Gemini',
        build: () => http.Request('POST', _endpoint(model))
          ..headers['x-goog-api-key'] = apiKey
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode(payload),
      );
    } on Object catch (error) {
      yield StreamErrorEvent(error: error);
      return;
    }

    final parser = GeminiEventParser();
    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final data = trimmed.substring(5).trim();
      if (data.isEmpty) continue;
      final Map<String, Object?> chunk;
      try {
        chunk = (jsonDecode(data) as Map).cast<String, Object?>();
      } on FormatException {
        continue;
      }
      for (final event in parser.parse(chunk)) {
        yield event;
      }
    }
  }

  /// Closes the underlying HTTP client. Call when the provider is discarded if
  /// it created its own client.
  void close() => _client.close();

  Uri _endpoint(String model) {
    final base = _baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/models/$model:streamGenerateContent?alt=sse');
  }

  /// Builds `systemInstruction` text and the `contents` array. Tool results are
  /// mapped to `functionResponse` parts, recovering the function name from the
  /// matching `functionCall` earlier in the conversation.
  (String?, List<Map<String, Object?>>) _buildContents(
    AiConversation conversation,
  ) {
    final systemBuffer = StringBuffer();
    final contents = <Map<String, Object?>>[];
    final toolNameById = <String, String>{};

    void add(String role, List<Map<String, Object?>> parts) {
      if (parts.isEmpty) return;
      contents.add({'role': role, 'parts': parts});
    }

    for (final message in conversation.messages) {
      switch (message.role) {
        case AiRole.system:
          if (message.text.isEmpty) break;
          if (systemBuffer.isNotEmpty) systemBuffer.write('\n\n');
          systemBuffer.write(message.text);
        case AiRole.user:
          add('user', [
            if (message.text.isNotEmpty) {'text': message.text},
            for (final image in _images(message)) _imagePart(image),
          ]);
        case AiRole.assistant:
          final calls = message.parts.whereType<ToolCallPart>();
          for (final call in calls) {
            toolNameById[call.toolCallId] = call.toolName;
          }
          add('model', [
            if (message.text.isNotEmpty) {'text': message.text},
            for (final call in calls)
              {
                'functionCall': {'name': call.toolName, 'args': call.args},
              },
          ]);
        case AiRole.tool:
          add('user', [
            for (final result in message.parts.whereType<ToolResultPart>())
              {
                'functionResponse': {
                  'name': toolNameById[result.toolCallId] ?? result.toolCallId,
                  'response': _asObject(result.result),
                },
              },
          ]);
      }
    }

    final system = systemBuffer.isEmpty ? null : systemBuffer.toString();
    return (system, contents);
  }

  /// Gemini's `functionResponse.response` must be an object; wrap scalars.
  Map<String, Object?> _asObject(Object? result) =>
      result is Map ? result.cast<String, Object?>() : {'result': result};

  static Iterable<FilePart> _images(AiMessage message) => message.parts
      .whereType<FilePart>()
      .where((f) => f.mediaType.startsWith('image/'));

  /// A Gemini image part: `inlineData` for inline bytes, else `fileData`.
  static Map<String, Object?> _imagePart(FilePart image) => image.bytes != null
      ? {
          'inlineData': {
            'mimeType': image.mediaType,
            'data': base64Encode(image.bytes!),
          },
        }
      : {
          'fileData': {
            'mimeType': image.mediaType,
            'fileUri': image.url.toString(),
          },
        };

  List<Map<String, Object?>>? _buildTools(List<ToolDefinition>? tools) {
    final hasFns = tools != null && tools.isNotEmpty;
    if (!hasFns && !enableGrounding) return null;
    return [
      if (hasFns)
        {
          'functionDeclarations': [
            for (final tool in tools)
              {
                'name': tool.name,
                'description': tool.description,
                'parameters': tool.parametersSchema,
              },
          ],
        },
      if (enableGrounding) {'googleSearch': <String, Object?>{}},
    ];
  }
}

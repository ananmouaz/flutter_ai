import 'dart:async';
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
///    `functionResponse` parts emitted in the SAME order as that turn's calls
///    (Gemini has no id channel and matches responses to calls by name +
///    position, so call order is preserved to keep duplicate-named calls aligned
///    with their own results).
///  * `temperature` / `maxOutputTokens` are sent under `generationConfig`.
///
/// > The request/response mapping is unit-tested against recorded SSE chunks;
/// > supply an API key to use it against the live API.
class GeminiProvider implements LlmProvider, EmbeddingProvider, TokenCounter {
  /// Creates a provider.
  ///
  /// [apiKey] authenticates requests (sent as `x-goog-api-key`). [baseUrl]
  /// defaults to the public Generative Language v1beta endpoint. [client] is
  /// injectable. [defaultModel] is used when [AiRequestOptions.model] is unset.
  /// [enableGrounding] adds the Google Search tool to every request. [timeout]
  /// bounds both the initial connection and the idle gap between streamed
  /// chunks.
  GeminiProvider({
    required this.apiKey,
    Uri? baseUrl,
    http.Client? client,
    this.defaultModel = 'gemini-2.5-flash',
    this.enableGrounding = false,
    this.maxRetries = 2,
    this.timeout = const Duration(seconds: 60),
  })  : assert(
          apiKey.isNotEmpty,
          'GeminiProvider: apiKey is empty — pass a key or set GEMINI_API_KEY '
          'via --dart-define.',
        ),
        _baseUrl = baseUrl ??
            Uri.parse('https://generativelanguage.googleapis.com/v1beta'),
        _ownsClient = client == null,
        _client = client ?? http.Client();

  /// The API key sent as the `x-goog-api-key` header.
  final String apiKey;

  /// The default model when options don't specify one.
  final String defaultModel;

  /// Whether to attach the Google Search grounding tool to every request.
  ///
  /// Note: the Gemini API rejects a request that contains **both** the
  /// `googleSearch` grounding tool and `functionDeclarations` (a 400). When
  /// function tools are supplied to `send`, the explicit tools take precedence
  /// and grounding is omitted for that request even if this is set.
  final bool enableGrounding;

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

  // Mints a unique message id per response — Gemini's stream carries no id of
  // its own, and a fixed id would make multi-turn replies fold into one message.
  int _responseSeq = 0;

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
      if (options?.responseFormat != null) ...{
        'responseMimeType': 'application/json',
        'responseSchema': options!.responseFormat!.schema,
      },
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
        timeout: timeout,
        build: () => http.Request('POST', _endpoint(model))
          ..headers['x-goog-api-key'] = apiKey
          ..headers['content-type'] = 'application/json'
          ..body = jsonEncode(payload),
      );
    } on Object catch (error) {
      yield StreamErrorEvent(error: error);
      return;
    }

    final parser = GeminiEventParser(messageId: 'gemini-${_responseSeq++}');
    // Idle timeout: a stall longer than [timeout] between chunks aborts the
    // `await for` with a TimeoutException instead of hanging forever.
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(timeout);
    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data.isEmpty) continue;
        try {
          final Map<String, Object?> chunk;
          try {
            chunk = (jsonDecode(data) as Map).cast<String, Object?>();
          } on FormatException {
            continue;
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
    // Stream ended — emit a terminal event if Gemini didn't send a finishReason.
    for (final event in parser.finalize()) {
      yield event;
    }
  }

  @override
  Future<List<AiEmbedding>> embed(List<String> inputs, {String? model}) async {
    final embedModel = model ?? 'text-embedding-004';
    final response = await _client.post(
      _modelEndpoint(embedModel, 'batchEmbedContents'),
      headers: {
        'x-goog-api-key': apiKey,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'requests': [
          for (final input in inputs)
            {
              'model': 'models/$embedModel',
              'content': {
                'parts': [
                  {'text': input},
                ],
              },
            },
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw llmExceptionFor(
        response.statusCode,
        'Gemini embeddings: ${response.body}',
      );
    }
    final decoded = (jsonDecode(response.body) as Map).cast<String, Object?>();
    final embeddings = (decoded['embeddings'] as List?) ?? const [];
    return [
      for (var i = 0; i < embeddings.length; i++)
        AiEmbedding(
          [
            for (final v in (embeddings[i] as Map)['values']! as List)
              (v as num).toDouble(),
          ],
          index: i,
        ),
    ];
  }

  @override
  Future<int> countTokens(
    AiConversation conversation, {
    List<ToolDefinition> tools = const [],
    AiRequestOptions? options,
  }) async {
    final (_, contents) = _buildContents(conversation);
    final model = options?.model ?? defaultModel;
    final response = await _client.post(
      _modelEndpoint(model, 'countTokens'),
      headers: {
        'x-goog-api-key': apiKey,
        'content-type': 'application/json',
      },
      body: jsonEncode({'contents': contents}),
    );
    if (response.statusCode != 200) {
      throw llmExceptionFor(
        response.statusCode,
        'Gemini countTokens: ${response.body}',
      );
    }
    final decoded = (jsonDecode(response.body) as Map).cast<String, Object?>();
    return (decoded['totalTokens'] as num).toInt();
  }

  /// Closes the underlying HTTP client, but only if this provider created it.
  /// When a `client` was injected, `close` is a no-op so a shared client isn't
  /// torn out from under its owner.
  void close() {
    if (_ownsClient) _client.close();
  }

  Uri _endpoint(String model) {
    final base = _baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/models/$model:streamGenerateContent?alt=sse');
  }

  Uri _modelEndpoint(String model, String method) {
    final base = _baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/models/$model:$method');
  }

  /// Builds `systemInstruction` text and the `contents` array. Tool results are
  /// mapped to `functionResponse` parts, recovering the function name from the
  /// matching `functionCall` earlier in the conversation.
  (String?, List<Map<String, Object?>>) _buildContents(
    AiConversation conversation,
  ) {
    final systemBuffer = StringBuffer();
    final contents = <Map<String, Object?>>[];
    // Gemini's wire format has no id channel for function calls/responses: it
    // matches a `functionResponse` to its `functionCall` by **function name +
    // positional order** within the turn. So we track, per assistant turn, the
    // ordered list of (id, name) for its calls. When the matching tool turn
    // arrives, we emit one `functionResponse` per call in that SAME order,
    // looking each result up by the internal tool-call id. This keeps two calls
    // to the same tool (e.g. search, search) lined up with their own results
    // even though the wire has no ids to disambiguate them.
    var pendingCalls = <({String id, String name})>[];

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
          final calls = message.parts.whereType<ToolCallPart>().toList();
          pendingCalls = [
            for (final call in calls)
              (id: call.toolCallId, name: call.toolName),
          ];
          add('model', [
            if (message.text.isNotEmpty) {'text': message.text},
            for (final call in calls)
              {
                'functionCall': {'name': call.toolName, 'args': call.args},
              },
          ]);
        case AiRole.tool:
          final resultsById = {
            for (final result in message.parts.whereType<ToolResultPart>())
              result.toolCallId: result,
          };
          // Emit responses in call order (keyed by name), so Gemini's
          // name+position matching lines up — including duplicate names.
          add('user', [
            for (final call in pendingCalls)
              if (resultsById[call.id] case final result?)
                {
                  'functionResponse': {
                    'name': call.name,
                    'response': _asObject(result.result),
                  },
                },
          ]);
          pendingCalls = const [];
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
      // Gemini 400s when `googleSearch` and `functionDeclarations` appear
      // together, so when explicit function tools are present we drop grounding
      // for this request rather than send an invalid combination.
      if (enableGrounding && !hasFns) {'googleSearch': <String, Object?>{}},
    ];
  }
}

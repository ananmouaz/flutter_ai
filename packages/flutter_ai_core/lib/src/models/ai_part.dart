import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_ai_core/src/internal/equality.dart';
import 'package:flutter_ai_core/src/models/tool_call_state.dart';

/// A single typed segment of an `AiMessage`.
///
/// A message is an ordered list of parts, mirroring the "parts" model used by
/// modern AI SDKs: a turn may interleave prose, reasoning, tool calls and their
/// results, files, and citations. [AiPart] is `sealed`, so a `switch` over a
/// part is exhaustively checked at compile time — adding a new part type forces
/// every consumer to handle it.
///
/// Every part serializes with a `type` discriminator. [AiPart.fromJson]
/// dispatches on that field; subclasses round-trip their own payload.
///
/// See also `AiMessage`, which owns an ordered list of parts.
sealed class AiPart {
  /// Const base constructor for subclasses.
  const AiPart();

  /// Reconstructs a part from its [json] map by dispatching on `type`.
  ///
  /// Throws a [FormatException] if `type` is missing or unrecognized.
  factory AiPart.fromJson(Map<String, Object?> json) {
    final type = json['type'];
    return switch (type) {
      'text' => TextPart.fromJson(json),
      'reasoning' => ReasoningPart.fromJson(json),
      'tool-call' => ToolCallPart.fromJson(json),
      'tool-result' => ToolResultPart.fromJson(json),
      'file' => FilePart.fromJson(json),
      'source' => SourcePart.fromJson(json),
      'data' => DataPart.fromJson(json),
      _ => throw FormatException('Unknown AiPart type: "$type"'),
    };
  }

  /// Serializes this part, including its `type` discriminator.
  Map<String, Object?> toJson();
}

/// Human- or model-authored prose, typically rendered as Markdown.
final class TextPart extends AiPart {
  /// Creates a text part holding [text].
  const TextPart(String text)
      : _text = text,
        _buffer = null,
        _bufferLength = 0;

  /// Reconstructs a [TextPart] from [json].
  factory TextPart.fromJson(Map<String, Object?> json) =>
      TextPart(json['text']! as String);

  /// Creates a text part whose content is accumulated in [buffer], materialized
  /// to a [String] lazily on first read of [text].
  ///
  /// Internal to the streaming reducer: appending deltas to one shared
  /// [StringBuffer] keeps accumulation linear (O(total length)) instead of
  /// reallocating the whole string on every delta. The expensive `toString()`
  /// happens only when a consumer actually reads the text (e.g. at a frame
  /// boundary), not once per token.
  ///
  /// This wrapper freezes at the buffer's length *at construction time* (see
  /// [text]): the reducer appends the next delta to the same buffer and wraps it
  /// in a *new* `TextPart`, so a previously returned conversation snapshot never
  /// observes the later appends. Value equality therefore holds mid-stream —
  /// two snapshots taken at different points compare unequal. Do not construct
  /// or read the [buffer] outside the reducer.
  TextPart.buffered(StringBuffer buffer)
      : _text = null,
        _buffer = buffer,
        _bufferLength = buffer.length;

  final String? _text;
  final StringBuffer? _buffer;

  /// The buffer's length (in UTF-16 code units) captured when this wrapper was
  /// created, freezing the prefix this part represents. See [TextPart.buffered].
  final int _bufferLength;

  /// The textual content.
  ///
  /// For a [TextPart.buffered] this materializes the backing buffer on demand,
  /// truncated to the prefix captured at construction so later appends to the
  /// shared buffer (which belong to newer snapshots) are never observed.
  String get text {
    final text = _text;
    if (text != null) return text;
    final buffer = _buffer!;
    final materialized = buffer.toString();
    return materialized.length == _bufferLength
        ? materialized
        : materialized.substring(0, _bufferLength);
  }

  /// The live accumulation buffer backing this part, or `null` for an ordinary
  /// part. Internal to the streaming reducer, which appends the next delta in
  /// place rather than rebuilding the string.
  StringBuffer? get buffer => _buffer;

  /// Returns a copy with [text] replaced.
  TextPart copyWith({String? text}) => TextPart(text ?? this.text);

  @override
  Map<String, Object?> toJson() => {'type': 'text', 'text': text};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TextPart && other.text == text);

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextPart(${text.length} chars)';
}

/// The model's intermediate reasoning ("chain of thought").
///
/// Surfaced separately from prose so the UI can disclose it in a collapsible
/// region rather than mixing it into the answer.
final class ReasoningPart extends AiPart {
  /// Creates a reasoning part holding [text].
  const ReasoningPart(String text, {this.signature})
      : _text = text,
        _buffer = null,
        _bufferLength = 0;

  /// Reconstructs a [ReasoningPart] from [json].
  factory ReasoningPart.fromJson(Map<String, Object?> json) => ReasoningPart(
        json['text']! as String,
        signature: json['signature'] as String?,
      );

  /// Creates a reasoning part whose content is accumulated in [buffer],
  /// materialized lazily on first read of [text].
  ///
  /// See [TextPart.buffered]: this keeps reasoning-delta accumulation linear
  /// rather than reallocating the whole string per delta, and freezes at the
  /// buffer length captured here so previously returned snapshots never observe
  /// later appends.
  ReasoningPart.buffered(StringBuffer buffer, {this.signature})
      : _text = null,
        _buffer = buffer,
        _bufferLength = buffer.length;

  final String? _text;
  final StringBuffer? _buffer;

  /// The buffer's length (in UTF-16 code units) captured when this wrapper was
  /// created, freezing the prefix this part represents. See [TextPart.buffered].
  final int _bufferLength;

  /// The reasoning content.
  ///
  /// For a [ReasoningPart.buffered] this materializes the backing buffer on
  /// demand, truncated to the prefix captured at construction.
  String get text {
    final text = _text;
    if (text != null) return text;
    final buffer = _buffer!;
    final materialized = buffer.toString();
    return materialized.length == _bufferLength
        ? materialized
        : materialized.substring(0, _bufferLength);
  }

  /// The live accumulation buffer backing this part, or `null` for an ordinary
  /// part. Internal to the streaming reducer.
  StringBuffer? get buffer => _buffer;

  /// An opaque provider signature for this reasoning block, when the provider
  /// supplies one (e.g. Anthropic extended thinking). It must be preserved and
  /// replayed verbatim on subsequent turns or the API rejects the request.
  final String? signature;

  /// Returns a copy with the given fields replaced.
  ReasoningPart copyWith({String? text, String? signature}) =>
      ReasoningPart(text ?? this.text, signature: signature ?? this.signature);

  @override
  Map<String, Object?> toJson() => {
        'type': 'reasoning',
        'text': text,
        if (signature != null) 'signature': signature,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReasoningPart &&
          other.text == text &&
          other.signature == signature);

  @override
  int get hashCode => Object.hash(text, signature);

  @override
  String toString() => 'ReasoningPart(${text.length} chars)';
}

/// A request from the model to invoke a tool.
///
/// During streaming, [args] fills in incrementally and [state] advances from
/// [ToolCallState.inputStreaming] to [ToolCallState.inputAvailable]. The
/// matching output arrives later as a [ToolResultPart] carrying the same
/// [toolCallId].
final class ToolCallPart extends AiPart {
  /// Creates a tool-call part.
  const ToolCallPart({
    required this.toolCallId,
    required this.toolName,
    this.args = const {},
    this.state = ToolCallState.inputStreaming,
  });

  /// Reconstructs a [ToolCallPart] from [json].
  factory ToolCallPart.fromJson(Map<String, Object?> json) => ToolCallPart(
        toolCallId: json['toolCallId']! as String,
        toolName: json['toolName']! as String,
        args: (json['args'] as Map?)?.cast<String, Object?>() ?? const {},
        state: ToolCallState.fromJson(json['state']! as String),
      );

  /// Correlates this call with its [ToolResultPart].
  final String toolCallId;

  /// The name of the tool being invoked.
  final String toolName;

  /// The (possibly partial) arguments decoded from the model's JSON.
  final Map<String, Object?> args;

  /// The lifecycle stage of this call.
  final ToolCallState state;

  /// Returns a copy with the given fields replaced.
  ToolCallPart copyWith({
    String? toolCallId,
    String? toolName,
    Map<String, Object?>? args,
    ToolCallState? state,
  }) =>
      ToolCallPart(
        toolCallId: toolCallId ?? this.toolCallId,
        toolName: toolName ?? this.toolName,
        args: args ?? this.args,
        state: state ?? this.state,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'tool-call',
        'toolCallId': toolCallId,
        'toolName': toolName,
        'args': args,
        'state': state.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolCallPart &&
          other.toolCallId == toolCallId &&
          other.toolName == toolName &&
          other.state == state &&
          deepEquals(other.args, args));

  @override
  int get hashCode => Object.hash(toolCallId, toolName, state, deepHash(args));

  @override
  String toString() =>
      'ToolCallPart($toolName, id: $toolCallId, state: ${state.name})';
}

/// The output of a tool, fed back to the model and shown to the user.
final class ToolResultPart extends AiPart {
  /// Creates a tool-result part.
  const ToolResultPart({
    required this.toolCallId,
    required this.result,
    this.isError = false,
  });

  /// Reconstructs a [ToolResultPart] from [json].
  factory ToolResultPart.fromJson(Map<String, Object?> json) => ToolResultPart(
        toolCallId: json['toolCallId']! as String,
        result: json['result'],
        isError: json['isError'] as bool? ?? false,
      );

  /// The id of the [ToolCallPart] this result answers.
  final String toolCallId;

  /// The tool's output. Any JSON-encodable value, or `null`.
  final Object? result;

  /// Whether [result] represents an error rather than a success payload.
  final bool isError;

  /// Returns a copy with the given fields replaced.
  ToolResultPart copyWith({
    String? toolCallId,
    Object? result,
    bool? isError,
  }) =>
      ToolResultPart(
        toolCallId: toolCallId ?? this.toolCallId,
        result: result ?? this.result,
        isError: isError ?? this.isError,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'tool-result',
        'toolCallId': toolCallId,
        'result': result,
        'isError': isError,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolResultPart &&
          other.toolCallId == toolCallId &&
          other.isError == isError &&
          deepEquals(other.result, result));

  @override
  int get hashCode => Object.hash(toolCallId, isError, deepHash(result));

  @override
  String toString() => 'ToolResultPart(id: $toolCallId, isError: $isError)';
}

/// A file attachment: an image, document, or audio clip.
///
/// Carries either a [url] (hosted/remote) or inline [bytes]. Document text
/// extraction is deliberately out of scope here — that is a backend concern, to
/// keep it off the UI thread.
final class FilePart extends AiPart {
  /// Creates a file part. Provide a [url], [bytes], or both.
  const FilePart({
    required this.mediaType,
    this.url,
    this.bytes,
    this.name,
  });

  /// Reconstructs a [FilePart] from [json].
  ///
  /// Inline [bytes] are expected as a base64 string under `bytes`.
  factory FilePart.fromJson(Map<String, Object?> json) {
    final encoded = json['bytes'] as String?;
    final url = json['url'] as String?;
    return FilePart(
      mediaType: json['mediaType']! as String,
      url: url == null ? null : Uri.parse(url),
      bytes: encoded == null ? null : base64Decode(encoded),
      name: json['name'] as String?,
    );
  }

  /// The IANA media type, e.g. `image/png` or `application/pdf`.
  final String mediaType;

  /// The remote location of the file, if hosted.
  final Uri? url;

  /// The inline contents of the file, if embedded.
  final Uint8List? bytes;

  /// A human-readable file name, if known.
  final String? name;

  /// Returns a copy with the given fields replaced.
  FilePart copyWith({
    String? mediaType,
    Uri? url,
    Uint8List? bytes,
    String? name,
  }) =>
      FilePart(
        mediaType: mediaType ?? this.mediaType,
        url: url ?? this.url,
        bytes: bytes ?? this.bytes,
        name: name ?? this.name,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'file',
        'mediaType': mediaType,
        if (url != null) 'url': url.toString(),
        if (bytes != null) 'bytes': base64Encode(bytes!),
        if (name != null) 'name': name,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilePart &&
          other.mediaType == mediaType &&
          other.url == url &&
          other.name == name &&
          deepEquals(other.bytes, bytes));

  @override
  int get hashCode =>
      Object.hash(mediaType, url, name, bytes == null ? null : deepHash(bytes));

  @override
  String toString() => 'FilePart($mediaType${name != null ? ', $name' : ''})';
}

/// A citation or source referenced by the model, rendered as a link or chip.
final class SourcePart extends AiPart {
  /// Creates a source part pointing at [url].
  const SourcePart({required this.url, this.title});

  /// Reconstructs a [SourcePart] from [json].
  factory SourcePart.fromJson(Map<String, Object?> json) => SourcePart(
        url: Uri.parse(json['url']! as String),
        title: json['title'] as String?,
      );

  /// The source location.
  final Uri url;

  /// A human-readable title for the source, if known.
  final String? title;

  @override
  Map<String, Object?> toJson() => {
        'type': 'source',
        'url': url.toString(),
        if (title != null) 'title': title,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourcePart && other.url == url && other.title == title);

  @override
  int get hashCode => Object.hash(url, title);

  @override
  String toString() => 'SourcePart($url)';
}

/// A structured data payload that drives generative UI.
///
/// The model emits a [dataType] naming a developer-registered widget plus a
/// [data] map of its inputs. Rendering is resolved against a strict catalog in
/// the UI layer — never via reflection — so only explicitly registered widgets
/// can be instantiated.
final class DataPart extends AiPart {
  /// Creates a data part of the given [dataType] carrying [data].
  const DataPart({required this.dataType, this.data = const {}});

  /// Reconstructs a [DataPart] from [json].
  factory DataPart.fromJson(Map<String, Object?> json) => DataPart(
        dataType: json['dataType']! as String,
        data: (json['data'] as Map?)?.cast<String, Object?>() ?? const {},
      );

  /// Names the registered widget this payload targets.
  final String dataType;

  /// The widget's inputs.
  final Map<String, Object?> data;

  /// Returns a copy with the given fields replaced.
  DataPart copyWith({String? dataType, Map<String, Object?>? data}) =>
      DataPart(dataType: dataType ?? this.dataType, data: data ?? this.data);

  @override
  Map<String, Object?> toJson() =>
      {'type': 'data', 'dataType': dataType, 'data': data};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DataPart &&
          other.dataType == dataType &&
          deepEquals(other.data, data));

  @override
  int get hashCode => Object.hash(dataType, deepHash(data));

  @override
  String toString() => 'DataPart($dataType)';
}

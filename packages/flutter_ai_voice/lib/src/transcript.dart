/// The result of transcribing an audio clip.
final class Transcript {
  /// Creates a transcript.
  const Transcript({required this.text, this.segments = const []});

  /// Reconstructs a [Transcript] from [json].
  factory Transcript.fromJson(Map<String, Object?> json) => Transcript(
        text: json['text']! as String,
        segments: [
          for (final segment in (json['segments'] as List?) ?? const [])
            TranscriptSegment.fromJson(
              (segment! as Map).cast<String, Object?>(),
            ),
        ],
      );

  /// The full transcribed text.
  final String text;

  /// Time-aligned segments, if the engine provides them.
  final List<TranscriptSegment> segments;

  /// Serializes this transcript.
  Map<String, Object?> toJson() => {
        'text': text,
        'segments': [for (final segment in segments) segment.toJson()],
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transcript &&
          other.text == text &&
          _segmentsEqual(other.segments, segments));

  @override
  int get hashCode => Object.hash(text, Object.hashAll(segments));

  @override
  String toString() => 'Transcript(${text.length} chars, '
      '${segments.length} segments)';
}

bool _segmentsEqual(List<TranscriptSegment> a, List<TranscriptSegment> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A time-aligned slice of a [Transcript].
final class TranscriptSegment {
  /// Creates a segment spanning [start]–[end].
  const TranscriptSegment({
    required this.text,
    required this.start,
    required this.end,
  });

  /// Reconstructs a [TranscriptSegment] from [json].
  factory TranscriptSegment.fromJson(Map<String, Object?> json) =>
      TranscriptSegment(
        text: json['text']! as String,
        start: Duration(milliseconds: (json['startMs']! as num).toInt()),
        end: Duration(milliseconds: (json['endMs']! as num).toInt()),
      );

  /// The segment text.
  final String text;

  /// Offset of the segment's start from the clip's beginning.
  final Duration start;

  /// Offset of the segment's end from the clip's beginning.
  final Duration end;

  /// Serializes this segment (durations as milliseconds).
  Map<String, Object?> toJson() => {
        'text': text,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSegment &&
          other.text == text &&
          other.start == start &&
          other.end == end);

  @override
  int get hashCode => Object.hash(text, start, end);

  @override
  String toString() => 'TranscriptSegment("$text", $start–$end)';
}

/// An incremental transcription result from a streaming session.
final class TranscriptPartial {
  /// Creates a partial result.
  const TranscriptPartial({required this.text, this.isFinal = false});

  /// The text recognized so far.
  final String text;

  /// Whether this is the final result for the utterance.
  final bool isFinal;

  @override
  String toString() => 'TranscriptPartial("$text", isFinal: $isFinal)';
}

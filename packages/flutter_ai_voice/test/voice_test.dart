import 'dart:typed_data';

import 'package:flutter_ai_voice/flutter_ai_voice.dart';
import 'package:test/test.dart';

void main() {
  group('Transcript JSON', () {
    test('round-trips with segments', () {
      const transcript = Transcript(
        text: 'hello world',
        segments: [
          TranscriptSegment(
            text: 'hello',
            start: Duration.zero,
            end: Duration(milliseconds: 500),
          ),
          TranscriptSegment(
            text: 'world',
            start: Duration(milliseconds: 500),
            end: Duration(seconds: 1),
          ),
        ],
      );
      final decoded = Transcript.fromJson(transcript.toJson());
      expect(decoded.text, 'hello world');
      expect(decoded.segments, transcript.segments);
    });
  });

  group('CallbackSpeechToText', () {
    Future<Transcript> echo(
      Uint8List audio, {
      String? mediaType,
      String? language,
    }) async =>
        Transcript(text: 'bytes:${audio.length} lang:$language');

    test('transcribeBytes delegates to the function', () async {
      final stt = CallbackSpeechToText(transcribe: echo);
      final result = await stt.transcribeBytes(
        Uint8List.fromList([1, 2, 3]),
        language: 'en',
      );
      expect(result.text, 'bytes:3 lang:en');
    });

    test('transcribeFile loads bytes then transcribes', () async {
      final stt = CallbackSpeechToText(
        transcribe: echo,
        fileLoader: (uri) async => Uint8List.fromList([0, 0]),
      );
      final result = await stt.transcribeFile(Uri.parse('file:///a.wav'));
      expect(result.text, 'bytes:2 lang:null');
    });

    test('transcribeFile without a loader throws UnsupportedError', () {
      final stt = CallbackSpeechToText(transcribe: echo);
      expect(
        () => stt.transcribeFile(Uri.parse('file:///a.wav')),
        throwsUnsupportedError,
      );
    });

    test('transcribeStream buffers the stream and emits a final result',
        () async {
      final stt = CallbackSpeechToText(transcribe: echo);
      final audio = Stream<Uint8List>.fromIterable([
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([3, 4, 5]),
      ]);
      final partials = await stt.transcribeStream(audio).toList();
      expect(partials, hasLength(1));
      expect(partials.single.isFinal, isTrue);
      expect(partials.single.text, 'bytes:5 lang:null');
    });
  });
}

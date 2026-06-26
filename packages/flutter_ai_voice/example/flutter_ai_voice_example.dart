// Adapts a (fake) transcription engine and transcribes a buffer.
//
// Run with: dart run example/flutter_ai_voice_example.dart
import 'dart:typed_data';

import 'package:flutter_ai_voice/flutter_ai_voice.dart';

Future<void> main() async {
  // A real app would call an on-device Whisper binding or a cloud API here.
  final stt = CallbackSpeechToText(
    transcribe: (audio, {mediaType, language}) async => Transcript(
      text: 'pretend transcription of ${audio.length} bytes',
    ),
  );

  final recorded = Uint8List.fromList(List<int>.filled(1024, 0));
  final transcript = await stt.transcribeBytes(recorded, mediaType: 'audio/wav');

  // Feed transcript.text into a UseChatController in a real app.
  print(transcript.text);
}

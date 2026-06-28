/// Native Google Gemini provider for the `flutter_ai` family.
///
/// `GeminiProvider` implements `LlmProvider` by streaming Gemini's
/// `streamGenerateContent` endpoint and mapping each chunk to `AiStreamEvent`s
/// via `GeminiEventParser`. Unlike the OpenAI-compatible Gemini endpoint, this
/// speaks Gemini's native protocol, so it supports **Google Search grounding**
/// (web-source citations), function calling, and thinking.
///
/// Re-exports `flutter_ai_core`.
library;

export 'package:flutter_ai_core/flutter_ai_core.dart';

export 'src/gemini_event_parser.dart';
export 'src/gemini_provider.dart';

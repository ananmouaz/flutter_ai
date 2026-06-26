/// OpenAI-compatible provider for the `flutter_ai` family.
///
/// `OpenAiProvider` implements `LlmProvider` by streaming the OpenAI Chat
/// Completions API and mapping each chunk to `AiStreamEvent`s via
/// `OpenAiChunkParser`. Works with the public OpenAI endpoint or any compatible
/// server (Azure OpenAI, proxies, local servers) through a custom base URL.
///
/// Re-exports `flutter_ai_core`.
library;

export 'package:flutter_ai_core/flutter_ai_core.dart';

export 'src/openai_chunk_parser.dart';
export 'src/openai_provider.dart';

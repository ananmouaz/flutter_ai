/// Anthropic (Claude) provider for the `flutter_ai` family.
///
/// `AnthropicProvider` implements `LlmProvider` by streaming the Anthropic
/// Messages API and mapping each event to `AiStreamEvent`s via
/// `AnthropicEventParser`. Supports text, extended thinking, tool use, and
/// finish reasons over an injectable HTTP client.
///
/// Re-exports `flutter_ai_core`.
library;

export 'package:flutter_ai_core/flutter_ai_core.dart';

export 'src/anthropic_event_parser.dart';
export 'src/anthropic_provider.dart';

/// Provider-neutral tool calling for the `flutter_ai` family.
///
/// Declare tools with `ToolSpec`, collect them in a `ToolRegistry` (which both
/// advertises `ToolDefinition`s to a provider and executes incoming tool calls
/// into `ToolResultPart`s), and expose web search as a tool via `webSearchTool`
/// over a host-provided `WebSearchAdapter`.
///
/// Pure Dart — no Flutter dependency. Re-exports `flutter_ai_core`.
library;

export 'package:flutter_ai_core/flutter_ai_core.dart';

export 'src/tool_registry.dart';
export 'src/tool_spec.dart';
export 'src/web_search.dart';

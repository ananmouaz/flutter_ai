import 'package:flutter/widgets.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/widgets/ai_tool_invocation.dart';

/// A vertically stacked list of [AiToolInvocation] cards — the recommended way
/// to present parallel tool calls.
///
/// Each call is paired with its result (by `toolCallId`) from [results], so the
/// user can inspect every action independently.
class AiToolGroup extends StatelessWidget {
  /// Creates a tool group for [calls], pairing each with its result in
  /// [results] (keyed by `toolCallId`).
  const AiToolGroup({
    super.key,
    required this.calls,
    this.results = const {},
    this.spacing = 8,
  });

  /// The tool calls to display, in order.
  final List<ToolCallPart> calls;

  /// Results keyed by `toolCallId`.
  final Map<String, ToolResultPart> results;

  /// Vertical gap between cards.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < calls.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          AiToolInvocation(
            call: calls[i],
            result: results[calls[i].toolCallId],
          ),
        ],
      ],
    );
  }
}

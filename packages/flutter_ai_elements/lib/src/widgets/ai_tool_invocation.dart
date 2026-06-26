import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_ai_core/flutter_ai_core.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A collapsible card showing a single tool call: its name, lifecycle state,
/// arguments, and (once available) result.
///
/// Stacking several of these vertically is the intended way to present parallel
/// tool calls — see `AiToolGroup`.
class AiToolInvocation extends StatefulWidget {
  /// Creates a tool-invocation card for [call] with an optional [result].
  const AiToolInvocation({
    super.key,
    required this.call,
    this.result,
    this.initiallyExpanded = false,
  });

  /// The tool call to display.
  final ToolCallPart call;

  /// The matching result, if it has arrived.
  final ToolResultPart? result;

  /// Whether the card starts expanded.
  final bool initiallyExpanded;

  @override
  State<AiToolInvocation> createState() => _AiToolInvocationState();
}

class _AiToolInvocationState extends State<AiToolInvocation> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final baseColor = DefaultTextStyle.of(context).style.color;
    final (icon, iconColor) = _statusVisual(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (baseColor ?? const Color(0xFF000000)).withValues(alpha: 0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.call.toolName,
                      style: theme.codeStyle.copyWith(color: baseColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _stateLabel(widget.call.state),
                    style: theme.codeStyle.copyWith(
                      color: baseColor?.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: baseColor?.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: theme.motionDuration,
            curve: theme.motionCurve,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Section(
                          label: 'Arguments',
                          body: _pretty(widget.call.args),
                          style: theme.codeStyle.copyWith(color: baseColor),
                        ),
                        if (widget.result != null) ...[
                          const SizedBox(height: 8),
                          _Section(
                            label: widget.result!.isError ? 'Error' : 'Result',
                            body: _pretty(widget.result!.result),
                            style: theme.codeStyle.copyWith(color: baseColor),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _statusVisual(BuildContext context) {
    final base =
        DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    return switch (_effectiveState()) {
      ToolCallState.error => (Icons.error_outline, const Color(0xFFDC2626)),
      ToolCallState.outputAvailable => (
          Icons.check_circle_outline,
          const Color(0xFF16A34A),
        ),
      _ => (Icons.build_outlined, base),
    };
  }

  // A result marked error overrides the call's own state for display.
  ToolCallState _effectiveState() {
    if (widget.result?.isError ?? false) return ToolCallState.error;
    return widget.call.state;
  }

  static String _stateLabel(ToolCallState state) => switch (state) {
        ToolCallState.inputStreaming => 'preparing…',
        ToolCallState.inputAvailable => 'ready',
        ToolCallState.executing => 'running…',
        ToolCallState.outputAvailable => 'done',
        ToolCallState.error => 'error',
      };

  static String _pretty(Object? value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } on Object {
      return '$value';
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.body,
    required this.style,
  });

  final String label;
  final String body;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: style.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: style.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(body, style: style),
      ],
    );
  }
}

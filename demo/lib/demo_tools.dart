import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// Tools advertised to the model. The model decides *if* and *when* to call
/// them; [ToolRunner] executes the calls and feeds results back.
///
/// Ask the live model things like "What's the weather in Lisbon?" or
/// "Book a hotel in Lisbon for 2 nights" to trigger them.
const List<ToolDefinition> demoTools = [
  ToolDefinition(
    name: 'get_weather',
    description: 'Get the current weather for a city. Call this whenever the '
        'user asks about weather.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string', 'description': 'City name, e.g. "Lisbon"'},
      },
      'required': ['city'],
    },
  ),
  ToolDefinition(
    name: 'book_hotel',
    description: 'Book a hotel room in a city for a number of nights. This '
        'charges the user, so it must be confirmed first.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string'},
        'nights': {'type': 'integer', 'description': 'Number of nights'},
      },
      'required': ['city', 'nights'],
    },
  ),
];

/// Drives the tool-call loop for the demo: when the model emits a tool call,
/// safe tools run immediately while sensitive ones wait for the user to confirm
/// — then results are sent back so the model can finish its answer. Supports
/// multiple rounds (a real agentic loop).
///
/// Only acts on calls the model leaves *open* (no result yet), so the scripted
/// [DemoChatProvider], whose tool calls already carry inline results, is
/// untouched. This makes the elements genuinely exercised by a live provider.
class ToolRunner extends ChangeNotifier {
  /// Watches [controller] and runs its tool calls.
  ToolRunner(this._controller) {
    _controller.addListener(_pump);
  }

  final UseChatController _controller;

  // Tools that require explicit user approval before they run.
  static const Set<String> _needsConfirmation = {'book_hotel'};

  final Map<String, ToolCallPart> _pending = {}; // awaiting confirmation
  final Map<String, ToolResultPart> _ready = {}; // executed, not yet sent
  final Set<String> _dispatched = {}; // results already sent to the model
  bool _busy = false;

  /// Tool calls awaiting user confirmation, keyed by tool-call id.
  Map<String, ToolCallPart> get pending => Map.unmodifiable(_pending);

  @override
  void dispose() {
    _controller.removeListener(_pump);
    super.dispose();
  }

  /// Confirms or rejects a sensitive tool call, then continues the loop.
  void resolveConfirmation(String toolCallId, {required bool approved}) {
    final call = _pending.remove(toolCallId);
    if (call == null) return;
    _ready[toolCallId] = _execute(call, approved: approved);
    notifyListeners();
    _pump();
  }

  /// Human-readable confirmation copy for a pending sensitive call.
  ({String title, String description}) confirmationFor(ToolCallPart call) {
    final city = call.args['city'] as String? ?? 'the city';
    final nights = (call.args['nights'] as num?)?.toInt() ?? 1;
    return (
      title: 'Book Hotel Lisboa in $city for $nights night${nights == 1 ? '' : 's'}?',
      description: 'Estimated total €${nights * 210} · free cancellation',
    );
  }

  void _pump() {
    if (_busy || _controller.status != ChatStatus.idle) return;
    final messages = _controller.messages;

    // Calls already answered anywhere in the transcript (incl. the scripted
    // provider's inline results) are left alone.
    final resolved = <String>{
      for (final m in messages)
        for (final p in m.parts)
          if (p is ToolResultPart) p.toolCallId,
    };

    final open = <ToolCallPart>[];
    for (final m in messages.reversed) {
      if (m.role != AiRole.assistant) continue;
      final calls = m.parts.whereType<ToolCallPart>();
      if (calls.isEmpty) continue;
      open.addAll(
        calls.where(
          (c) =>
              !resolved.contains(c.toolCallId) &&
              !_dispatched.contains(c.toolCallId),
        ),
      );
      break; // only the most recent assistant turn can have open calls
    }
    if (open.isEmpty) return;

    // Resolve each: auto-run safe tools, queue sensitive ones for confirmation.
    for (final call in open) {
      final id = call.toolCallId;
      if (_ready.containsKey(id) || _pending.containsKey(id)) continue;
      if (_needsConfirmation.contains(call.toolName)) {
        _pending[id] = call;
      } else {
        _ready[id] = _execute(call, approved: true);
      }
    }
    notifyListeners();

    // Providers need a result for *every* call before continuing, so only send
    // once all open calls are ready (none awaiting confirmation).
    if (open.every((c) => _ready.containsKey(c.toolCallId))) {
      final results = [for (final c in open) _ready.remove(c.toolCallId)!];
      for (final c in open) {
        _dispatched.add(c.toolCallId);
      }
      _busy = true;
      unawaited(
        _controller.addToolResults(results).whenComplete(() {
          _busy = false;
          _pump(); // a further tool round may follow
        }),
      );
    }
  }

  // Mock implementations — a real app would call its backend here.
  ToolResultPart _execute(ToolCallPart call, {required bool approved}) {
    final id = call.toolCallId;
    if (!approved) {
      return ToolResultPart(
        toolCallId: id,
        result: {'status': 'declined', 'note': 'User did not approve.'},
        isError: true,
      );
    }
    switch (call.toolName) {
      case 'get_weather':
        final city = call.args['city'] as String? ?? 'your city';
        return ToolResultPart(
          toolCallId: id,
          result: {'city': city, 'tempC': 22, 'condition': 'Sunny'},
        );
      case 'book_hotel':
        final city = call.args['city'] as String? ?? 'the city';
        final nights = (call.args['nights'] as num?)?.toInt() ?? 1;
        return ToolResultPart(
          toolCallId: id,
          result: {
            'status': 'booked',
            'hotel': 'Hotel Lisboa',
            'city': city,
            'nights': nights,
            'totalEur': nights * 210,
            'confirmation': 'LSB-${1000 + nights}',
          },
        );
      default:
        return ToolResultPart(
          toolCallId: id,
          result: {'status': 'unknown tool: ${call.toolName}'},
          isError: true,
        );
    }
  }
}

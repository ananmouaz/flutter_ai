import 'package:flutter_ai_core/flutter_ai_core.dart';

/// History-trimming strategies for `UseChatController.trimHistory`.
///
/// A strategy maps the full stored conversation to the (smaller) conversation
/// sent to the provider. The controller never trims its stored transcript, so
/// these only bound what each request costs — the UI keeps the full history.
///
/// Both built-ins always preserve leading `system` messages and avoid starting
/// the kept window on an orphaned `tool` result (which strict providers
/// reject). Conversations with deeply interleaved tool calls may still need a
/// bespoke strategy — these are pragmatic defaults, not a general solution.

/// Keeps the system prefix plus the most recent [count] non-system messages.
///
/// If the kept window would begin on a `tool` message (a result whose
/// originating assistant tool-call would be trimmed away), the window is
/// advanced forward past it so no orphaned tool result is sent.
AiConversation Function(AiConversation) keepLastMessages(int count) {
  assert(count >= 0, 'count must be >= 0');
  return (conversation) {
    final messages = conversation.messages;
    final system = [
      for (final m in messages)
        if (m.role == AiRole.system) m,
    ];
    final rest = [
      for (final m in messages)
        if (m.role != AiRole.system) m,
    ];
    if (rest.length <= count) return conversation;

    var start = rest.length - count;
    while (start < rest.length && rest[start].role == AiRole.tool) {
      start++;
    }
    return conversation.copyWith(messages: [...system, ...rest.sublist(start)]);
  };
}

/// Keeps the system prefix plus as many of the most recent non-system messages
/// as fit within [maxTokens], estimated from text length.
///
/// Token counts are approximated as `ceil(textLength / charsPerToken)` per
/// message (default ~4 characters per token — a reasonable English heuristic;
/// use a provider `countTokens` for exact budgeting). System messages are
/// always kept and counted. As with [keepLastMessages], the window is advanced
/// past a leading `tool` result so none is orphaned.
AiConversation Function(AiConversation) trimToApproxTokenBudget(
  int maxTokens, {
  int charsPerToken = 4,
}) {
  assert(maxTokens >= 0, 'maxTokens must be >= 0');
  assert(charsPerToken >= 1, 'charsPerToken must be >= 1');
  int estimate(AiMessage m) => (m.text.length / charsPerToken).ceil();

  return (conversation) {
    final messages = conversation.messages;
    final system = [
      for (final m in messages)
        if (m.role == AiRole.system) m,
    ];
    final rest = [
      for (final m in messages)
        if (m.role != AiRole.system) m,
    ];

    var budget = maxTokens;
    for (final m in system) {
      budget -= estimate(m);
    }

    // Walk newest -> oldest, keeping messages until the budget is exhausted.
    final keptReversed = <AiMessage>[];
    for (var i = rest.length - 1; i >= 0; i--) {
      final cost = estimate(rest[i]);
      if (keptReversed.isNotEmpty && budget - cost < 0) break;
      budget -= cost;
      keptReversed.add(rest[i]);
    }
    var kept = keptReversed.reversed.toList();

    // Don't begin on an orphaned tool result.
    while (kept.isNotEmpty && kept.first.role == AiRole.tool) {
      kept = kept.sublist(1);
    }

    if (kept.length == rest.length) return conversation;
    return conversation.copyWith(messages: [...system, ...kept]);
  };
}

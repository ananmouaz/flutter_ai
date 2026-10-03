import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// Tool name of the one action that needs the user's approval in the recipe.
const String bookTableTool = 'book_table';

/// A scripted agent backend for the production recipe.
///
/// It stands in for a hosted agent: research tools run "server-side" and
/// stream their results inline, while [bookTableTool] is returned to the app
/// unanswered so the host decides whether it runs. Each scenario exercises one
/// state of the ask → progress → answer/sources → follow-up journey:
///
/// - anything else: three research steps, an answer, sources, follow-ups;
/// - "flight": fails on the first attempt so the retry path is visible;
/// - "passport": asks a structured question; the answer ("Remind me …")
///   yields an actionable result card;
/// - "table": proposes a booking that waits for approval.
class ProductionAgentProvider implements LlmProvider {
  /// Creates the provider. [delay] paces every streamed event.
  ProductionAgentProvider({this.delay = const Duration(milliseconds: 160)});

  /// Delay between emitted events.
  final Duration delay;

  // Prompts that already failed once; their retry succeeds.
  final Set<String> _failedOnce = {};

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) {
    final id = 'run-${conversation.messages.length}';
    final last = conversation.lastMessage;
    if (last?.role == AiRole.tool) {
      final result = last!.parts.whereType<ToolResultPart>().first;
      return _booked(id, result);
    }
    final prompt = conversation.messages
        .lastWhere((m) => m.role == AiRole.user)
        .text
        .toLowerCase();
    if (prompt.contains('flight')) {
      return _failedOnce.add(prompt) ? _flightFails(id) : _flight(id);
    }
    if (prompt.contains('passport')) return _passport(id);
    if (prompt.startsWith('remind me')) return _reminder(id);
    if (prompt.contains('table')) return _table(id);
    return _trains(id);
  }

  Future<AiStreamEvent> _step(AiStreamEvent event, [int beats = 1]) async {
    await Future<void>.delayed(delay * beats);
    return event;
  }

  Stream<AiStreamEvent> _text(String id, String text) async* {
    // Word-sized deltas, like a real stream.
    final words = text.split(' ');
    for (var i = 0; i < words.length; i += 3) {
      final chunk = words.skip(i).take(3).join(' ');
      yield await _step(
        TextDelta(messageId: id, delta: i == 0 ? chunk : ' $chunk'),
      );
    }
  }

  Stream<AiStreamEvent> _tool(
    String id,
    String tag,
    String name,
    String args, [
    Map<String, Object?>? result,
  ]) async* {
    final callId = '$id-$tag';
    yield await _step(
      ToolCallStarted(messageId: id, toolCallId: callId, toolName: name),
    );
    yield await _step(ToolCallDelta(toolCallId: callId, argumentsDelta: args));
    yield await _step(ToolCallReady(toolCallId: callId));
    if (result == null) return;
    yield await _step(
      ToolResultReceived(messageId: id, toolCallId: callId, result: result),
      4,
    );
  }

  Stream<AiStreamEvent> _sources(
    String id,
    List<(String, String)> list,
  ) async* {
    for (final (url, title) in list) {
      yield await _step(
        PartReceived(
          messageId: id,
          part: SourcePart(url: Uri.parse(url), title: title),
        ),
      );
    }
  }

  Stream<AiStreamEvent> _followUps(String id, List<String> items) async* {
    yield await _step(
      PartReceived(
        messageId: id,
        part: DataPart(dataType: 'follow_ups', data: {'items': items}),
      ),
    );
  }

  AiStreamEvent _finish(String id, [FinishReason r = FinishReason.stop]) =>
      MessageFinished(messageId: id, reason: r);

  Stream<AiStreamEvent> _trains(String id) async* {
    yield MessageStarted(messageId: id, role: AiRole.assistant);
    yield* _tool(
      id,
      'search',
      'search_web',
      '{"query":"Lisbon to Porto '
          'trains Saturday"}',
      {'results': 6},
    );
    yield* _tool(id, 'read', 'read_page', '{"url":"https://www.cp.pt"}', {
      'departures': 14,
    });
    yield* _tool(id, 'compare', 'compare_fares', '{"options":3}', {
      'cheapest': 'IC 523',
      'fastest': 'AP 133',
    });
    yield* _text(
      id,
      'The **Alfa Pendular AP 133** is the best pick: it leaves Lisboa '
      'Santa Apolónia at 09:00 and reaches Porto Campanhã at 11:49.\n\n'
      '- **Fastest:** Alfa Pendular, about 2 h 49 min, from €31.\n'
      '- **Cheapest:** Intercidades IC 523, about 3 h 15 min, from €25.\n'
      '- **Tip:** Saturday morning trains sell out, so book a day ahead.',
    );
    yield* _sources(id, const [
      ('https://www.cp.pt/passageiros/en/train-times', 'CP train times'),
      ('https://www.cp.pt/passageiros/en/tickets', 'CP tickets and fares'),
      ('https://www.visitporto.travel/en-GB', 'Visit Porto'),
      ('https://www.seat61.com/Portugal.htm', 'Seat61: Trains in Portugal'),
    ]);
    yield* _followUps(id, const [
      'Is first class worth it on the Alfa Pendular?',
      'What can I see in Porto in one day?',
      'Book a table for two in Porto tonight',
    ]);
    yield await _step(_finish(id));
  }

  Stream<AiStreamEvent> _flightFails(String id) async* {
    yield MessageStarted(messageId: id, role: AiRole.assistant);
    yield* _tool(id, 'status', 'flight_status', '{"flight":"TP 1350"}');
    yield await _step(
      StreamErrorEvent(
        messageId: id,
        error: "The flight status service didn't respond.",
      ),
      6,
    );
  }

  Stream<AiStreamEvent> _flight(String id) async* {
    yield MessageStarted(messageId: id, role: AiRole.assistant);
    yield* _tool(id, 'status', 'flight_status', '{"flight":"TP 1350"}', {
      'status': 'on time',
      'gate': '14',
    });
    yield* _text(
      id,
      'Flight **TP 1350** is on time. Boarding starts at 18:05 at gate 14, '
      'and it departs at 18:40.',
    );
    yield* _sources(id, const [
      ('https://www.flytap.com/en-us/flight-status', 'TAP flight status'),
    ]);
    yield* _followUps(id, const [
      'How long is the walk to gate 14?',
      'Which terminal does it leave from?',
    ]);
    yield await _step(_finish(id));
  }

  Stream<AiStreamEvent> _passport(String id) async* {
    yield MessageStarted(messageId: id, role: AiRole.assistant);
    yield* _tool(id, 'calendar', 'check_calendar', '{"query":"passport"}', {
      'expires': '2027-03-12',
    });
    yield* _text(
      id,
      'Your passport expires on **12 March 2027**. Renewal usually takes '
      'about four weeks.',
    );
    yield await _step(
      PartReceived(
        messageId: id,
        part: const DataPart(
          dataType: 'question',
          data: {
            'prompt': 'When should I remind you?',
            'options': [
              {'value': 'month', 'label': 'A month before'},
              {'value': 'quarter', 'label': 'Three months before'},
            ],
          },
        ),
      ),
    );
    yield await _step(_finish(id));
  }

  Stream<AiStreamEvent> _reminder(String id) async* {
    yield MessageStarted(messageId: id, role: AiRole.assistant);
    yield* _text(id, "Here's the reminder. Add it, or edit it first.");
    yield await _step(
      PartReceived(
        messageId: id,
        part: const DataPart(
          dataType: 'result_card',
          data: {
            'title': 'Renew your passport',
            'when': 'Tue 12 Jan 2027 · 09:00',
            'detail': 'Book an appointment and bring two photos.',
          },
        ),
      ),
    );
    yield* _followUps(id, const ['Which documents do I need to renew?']);
    yield await _step(_finish(id));
  }

  Stream<AiStreamEvent> _table(String id) async* {
    yield MessageStarted(messageId: id, role: AiRole.assistant);
    yield* _tool(id, 'search', 'search_restaurants', '{"party":2}', {
      'match': 'Taberna da Rua',
    });
    yield* _text(
      id,
      '**Taberna da Rua** has a table for two at 20:00. I need your '
      'approval before I book it.',
    );
    yield* _tool(
      id,
      'book',
      bookTableTool,
      '{"restaurant":"Taberna da Rua","time":"20:00","party":2}',
    );
    yield await _step(_finish(id, FinishReason.toolCalls));
  }

  Stream<AiStreamEvent> _booked(String id, ToolResultPart result) async* {
    yield MessageStarted(messageId: id, role: AiRole.assistant);
    final booked = !result.isError;
    yield* _text(
      id,
      booked
          ? 'Booked. Your table for two at **Taberna da Rua** is at 20:00 '
                '(confirmation TR-2041).'
          : "OK, I didn't book anything.",
    );
    yield* _followUps(id, [
      if (booked) 'Add the booking to my calendar' else 'Find another place',
    ]);
    yield await _step(_finish(id));
  }
}

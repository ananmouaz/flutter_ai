import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// A scripted [LlmProvider] with everyday mobile-chat scenarios (trip planning,
/// a recipe, summarizing an article) so the elements appear in realistic use.
///
/// Structured widgets ride along as `DataPart`s; the demo's `messageBuilder`
/// maps them to elements (a tiny generative-UI catalog). A prompt containing
/// "error" streams a failure to demo the error path.
class DemoChatProvider implements LlmProvider {
  /// Creates a demo provider with a per-event [delay] for a streaming feel.
  const DemoChatProvider({this.delay = const Duration(milliseconds: 95)});

  /// Delay between emitted events.
  final Duration delay;

  static const String _id = 'assistant';

  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) {
    final prompt = conversation.lastMessage?.text.toLowerCase() ?? '';
    if (prompt.contains('error')) return _error();
    if (prompt.contains('recipe') ||
        prompt.contains('dinner') ||
        prompt.contains('cook')) {
      return _recipe();
    }
    if (prompt.contains('summar')) return _summary();
    return _trip();
  }

  Future<AiStreamEvent> _step(AiStreamEvent event) async {
    await Future<void>.delayed(delay);
    return event;
  }

  Stream<AiStreamEvent> _error() async* {
    yield const MessageStarted(messageId: _id, role: AiRole.assistant);
    yield await _step(
      const ReasoningDelta(messageId: _id, delta: 'Attempting the request…'),
    );
    yield await _step(
      const StreamErrorEvent(
        error: 'The upstream service timed out. Please try again.',
        messageId: _id,
      ),
    );
  }

  Stream<AiStreamEvent> _trip() async* {
    yield const MessageStarted(messageId: _id, role: AiRole.assistant);
    yield await _step(
      const PartReceived(
        messageId: _id,
        part: DataPart(
          dataType: 'chain_of_thought',
          data: {
            'steps': [
              {'label': 'Check the weekend weather'},
              {'label': 'Find the top sights'},
              {'label': 'Build a 2-day plan', 'active': true},
            ],
          },
        ),
      ),
    );
    yield await _step(
      const TextDelta(
        messageId: _id,
        delta: "Lisbon is a great pick — here's a quick weekend plan.",
      ),
    );
    yield await _step(
      const PartReceived(
        messageId: _id,
        part: DataPart(
          dataType: 'task',
          data: {
            'title': 'Trip checklist',
            'items': [
              {'label': 'Book flights', 'status': 'complete'},
              {'label': 'Reserve a hotel', 'status': 'active'},
              {'label': 'Pack essentials', 'status': 'pending'},
            ],
          },
        ),
      ),
    );
    yield* _tool('get_weather', '{"city":"Lisbon"}', {
      'tempC': 24,
      'condition': 'Sunny',
    });
    yield await _step(
      const TextDelta(
        messageId: _id,
        delta: '## Day 1\n'
            '- Morning: Belém Tower and pastéis de nata\n'
            '- Afternoon: wander Alfama and São Jorge Castle\n\n'
            '## Day 2\n'
            '- Morning: Time Out Market\n'
            '- Afternoon: day trip to Sintra\n\n'
            'The forecast is **sunny, ~24°C** — pack light!',
      ),
    );
    yield* _image('lisbon');
    yield* _sources(const [
      ('https://www.timeout.com/lisbon', 'timeout.com'),
      ('https://www.lonelyplanet.com/portugal/lisbon', 'lonelyplanet.com'),
    ]);
    yield await _step(
      const MessageFinished(messageId: _id, reason: FinishReason.stop),
    );
  }

  Stream<AiStreamEvent> _recipe() async* {
    yield const MessageStarted(messageId: _id, role: AiRole.assistant);
    yield await _step(
      const PartReceived(
        messageId: _id,
        part: DataPart(
          dataType: 'chain_of_thought',
          data: {
            'steps': [
              {'label': 'Look for something quick'},
              {'label': 'Pick a crowd-pleaser', 'active': true},
            ],
          },
        ),
      ),
    );
    yield await _step(
      const TextDelta(
        messageId: _id,
        delta: 'How about one-pan lemon chicken? Ready in about 30 minutes.',
      ),
    );
    yield await _step(
      const PartReceived(
        messageId: _id,
        part: DataPart(
          dataType: 'task',
          data: {
            'title': 'Ingredients',
            'items': [
              {'label': 'Chicken thighs', 'status': 'complete'},
              {'label': 'Lemon & garlic', 'status': 'complete'},
              {'label': 'Baby spinach', 'status': 'pending'},
            ],
          },
        ),
      ),
    );
    yield* _tool('search_recipes', '{"q":"30 minute dinner"}', {'results': 5});
    yield await _step(
      const TextDelta(
        messageId: _id,
        delta: '## Steps\n'
            '1. Sear the chicken 5 minutes per side\n'
            '2. Add garlic, lemon, and a splash of stock\n'
            '3. Simmer 10 minutes, then stir in the spinach\n\n'
            '**Tip:** serve over rice or with crusty bread.',
      ),
    );
    yield* _image('dinner');
    yield* _sources(const [
      ('https://www.bbcgoodfood.com', 'bbcgoodfood.com'),
    ]);
    yield await _step(
      const MessageFinished(messageId: _id, reason: FinishReason.stop),
    );
  }

  Stream<AiStreamEvent> _summary() async* {
    yield const MessageStarted(messageId: _id, role: AiRole.assistant);
    yield await _step(
      const ReasoningDelta(
        messageId: _id,
        delta: 'Skimming the article for the key points.',
      ),
    );
    yield await _step(
      const TextDelta(
        messageId: _id,
        delta: '**Summary**\n\nThe article makes three points:\n\n'
            '- Streaming UIs must batch updates to stay smooth\n'
            '- Tool calls should be inspectable, not hidden\n'
            '- Citations build user trust\n\n'
            'Overall, a strong case for *structured* AI interfaces.',
      ),
    );
    yield* _sources(const [
      ('https://www.smashingmagazine.com', 'smashingmagazine.com'),
      ('https://www.nngroup.com', 'nngroup.com'),
    ]);
    yield await _step(
      const MessageFinished(messageId: _id, reason: FinishReason.stop),
    );
  }

  Stream<AiStreamEvent> _tool(
    String name,
    String args,
    Map<String, Object?> result,
  ) async* {
    yield await _step(
      ToolCallStarted(messageId: _id, toolCallId: 't1', toolName: name),
    );
    yield await _step(ToolCallDelta(toolCallId: 't1', argumentsDelta: args));
    yield await _step(const ToolCallReady(toolCallId: 't1'));
    yield await _step(
      ToolResultReceived(messageId: _id, toolCallId: 't1', result: result),
    );
  }

  Stream<AiStreamEvent> _image(String seed) async* {
    yield await _step(
      PartReceived(
        messageId: _id,
        part: FilePart(
          mediaType: 'image/jpeg',
          url: Uri.parse('https://picsum.photos/seed/$seed/640/360'),
          name: '$seed.jpg',
        ),
      ),
    );
  }

  Stream<AiStreamEvent> _sources(List<(String, String)> sources) async* {
    for (final (url, title) in sources) {
      yield await _step(
        PartReceived(
          messageId: _id,
          part: SourcePart(url: Uri.parse(url), title: title),
        ),
      );
    }
  }
}

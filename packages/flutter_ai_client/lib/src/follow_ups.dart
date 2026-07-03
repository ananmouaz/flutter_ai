import 'package:flutter_ai_core/flutter_ai_core.dart';

/// Generates up to [count] short follow-up prompts a user might send next, given
/// the current [conversation], via a one-off call to [provider].
///
/// This is the model call the presentational `AiSuggestions` strip needs to show
/// *contextual* follow-ups (it renders whatever list you give it). Returns an
/// empty list if the model produces nothing usable; it never throws for an empty
/// or malformed reply.
///
/// ```dart
/// final followUps = await suggestFollowUps(controller.conversation, provider);
/// // → feed into AiSuggestions(suggestions: followUps, onSelected: ...)
/// ```
///
/// Pass [options] to pick a cheaper/faster model for this side call (e.g. a
/// flash/mini model) independent of the main chat model.
Future<List<String>> suggestFollowUps(
  AiConversation conversation,
  LlmProvider provider, {
  int count = 3,
  AiRequestOptions? options,
}) async {
  if (conversation.messages.isEmpty) return const [];

  final prompt = AiMessage.text(
    id: 'follow-ups-prompt',
    role: AiRole.user,
    text: 'Based on the conversation so far, suggest $count brief follow-up '
        'questions I might ask next. Keep each under 8 words. '
        'Respond with one question per line, no numbering, bullets, or quotes.',
  );
  final request = conversation.copyWith(
    messages: [...conversation.messages, prompt],
  );

  final buffer = StringBuffer();
  await for (final event in provider.send(request, options: options)) {
    if (event is TextDelta) buffer.write(event.delta);
  }

  return _parseLines(buffer.toString(), count);
}

/// Splits the model reply into clean one-line suggestions, stripping any
/// leftover numbering/bullets/quotes and dropping blanks.
List<String> _parseLines(String reply, int count) {
  final cleaned = <String>[];
  for (final raw in reply.split('\n')) {
    var line = raw.trim();
    if (line.isEmpty) continue;
    // Strip a leading "1.", "1)", "-", "*", "•" list marker.
    line = line.replaceFirst(RegExp(r'^\s*(\d+[.)]|[-*•])\s*'), '');
    // Strip surrounding quotes.
    line = line.replaceAll(RegExp(r'''^["']+|["']+$'''), '').trim();
    if (line.isEmpty) continue;
    cleaned.add(line);
    if (cleaned.length >= count) break;
  }
  return cleaned;
}

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// A bespoke skin layered on the mobile-first default, used across the demo.
final AiThemeExtension demoTheme = AiThemeExtension.fallback().copyWith(
  userBubbleColor: const Color(0xFF6D28D9),
  assistantBubbleColor: const Color(0xFFF3F1FA),
  bubbleRadius: const BorderRadius.all(Radius.circular(22)),
);

/// One entry in the element gallery.
typedef GalleryItem = ({String name, String title, Widget child});

final Uri _weatherUri = Uri.parse('https://weather.example.com/london');

/// A rich assistant message exercising several part types at once.
final AiMessage richAssistantMessage = AiMessage(
  id: 'a-rich',
  role: AiRole.assistant,
  parts: [
    const ReasoningPart(
      'The user wants current weather, so I should call a tool.',
    ),
    const TextPart('Let me check the weather for you.'),
    const ToolCallPart(
      toolCallId: 'call_1',
      toolName: 'get_weather',
      args: {'city': 'London'},
      state: ToolCallState.outputAvailable,
    ),
    const ToolResultPart(
      toolCallId: 'call_1',
      result: {'tempC': 18, 'condition': 'Rainy'},
    ),
    const TextPart("It's 18°C and rainy in London — bring an umbrella!"),
    SourcePart(url: _weatherUri, title: 'weather.example.com'),
  ],
);

/// The elements gallery, each wrapped for display and screenshotting.
List<GalleryItem> galleryItems() => [
      (
        name: 'message_user',
        title: 'AiMessageBubble — user',
        child: const AiMessageBubble(
          message: AiMessage(
            id: 'u1',
            role: AiRole.user,
            parts: [TextPart('What is the weather in London today?')],
          ),
        ),
      ),
      (
        name: 'message_assistant',
        title: 'AiMessageBubble — assistant (rich)',
        child: AiMessageBubble(message: richAssistantMessage),
      ),
      (
        name: 'loader',
        title: 'AiLoader',
        child: const AiLoader(),
      ),
      (
        name: 'reasoning',
        title: 'AiReasoning',
        child: const AiReasoning(
          text: 'First, identify the city. Then call the weather tool and '
              'summarize the result for the user.',
          initiallyExpanded: true,
        ),
      ),
      (
        name: 'tool_invocation',
        title: 'AiToolInvocation',
        child: const AiToolInvocation(
          call: ToolCallPart(
            toolCallId: 'c1',
            toolName: 'get_weather',
            args: {'city': 'London', 'units': 'metric'},
            state: ToolCallState.outputAvailable,
          ),
          result: ToolResultPart(
            toolCallId: 'c1',
            result: {'tempC': 18, 'condition': 'Rainy'},
          ),
          initiallyExpanded: true,
        ),
      ),
      (
        name: 'tool_group',
        title: 'AiToolGroup — parallel calls',
        child: const AiToolGroup(
          calls: [
            ToolCallPart(
              toolCallId: 'c1',
              toolName: 'get_weather',
              state: ToolCallState.outputAvailable,
            ),
            ToolCallPart(
              toolCallId: 'c2',
              toolName: 'web_search',
              state: ToolCallState.executing,
            ),
          ],
          results: {
            'c1': ToolResultPart(toolCallId: 'c1', result: {'tempC': 18}),
          },
        ),
      ),
      (
        name: 'attachment',
        title: 'AiAttachment',
        child: const AiAttachment(
          file: FilePart(mediaType: 'application/pdf', name: 'itinerary.pdf'),
        ),
      ),
      (
        name: 'sources',
        title: 'AiSources',
        child: AiSources(
          sources: [
            SourcePart(url: _weatherUri, title: 'weather.example.com'),
            SourcePart(url: Uri.parse('https://flutter.dev'), title: 'Flutter'),
          ],
        ),
      ),
      (
        name: 'code_block',
        title: 'AiCodeBlock',
        child: const AiCodeBlock(
          language: 'dart',
          code: "void main() {\n  print('Hello, flutter_ai!');\n}",
        ),
      ),
      (
        name: 'suggestions',
        title: 'AiSuggestions',
        child: AiSuggestions(
          suggestions: const ['Summarize this', 'Translate to French', 'Explain'],
          onSelected: (_) {},
        ),
      ),
      (
        name: 'avatars',
        title: 'AiAvatar',
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AiAvatar(role: AiRole.user),
            SizedBox(width: 12),
            AiAvatar(role: AiRole.assistant),
          ],
        ),
      ),
      (
        name: 'empty_state',
        title: 'AiEmptyState',
        child: const SizedBox(
          height: 220,
          child: AiEmptyState(
            title: 'Ask me anything',
            subtitle: 'Your AI assistant is ready to help.',
          ),
        ),
      ),
      (
        name: 'error_banner',
        title: 'AiErrorBanner',
        child: AiErrorBanner(
          message: 'The request timed out.',
          onRetry: () {},
          onDismiss: () {},
        ),
      ),
      (
        name: 'message_actions',
        title: 'AiMessageActions',
        child: AiMessageActions(
          message: const AiMessage(
            id: 'm',
            role: AiRole.assistant,
            parts: [TextPart('hi')],
          ),
          onRegenerate: () {},
          onEdit: () {},
        ),
      ),
      (
        name: 'composer_idle',
        title: 'AiComposer — idle',
        child: AiComposer(onSend: (_) {}),
      ),
      (
        name: 'composer_busy',
        title: 'AiComposer — streaming (Stop)',
        child: AiComposer(onSend: (_) {}, onStop: () {}, isBusy: true),
      ),
    ];

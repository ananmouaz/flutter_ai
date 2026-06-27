import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// The demo uses the package's modern default skin as-is.
final AiThemeExtension demoTheme = AiThemeExtension.fallback();

/// A tiny 1×1 PNG, used to fake a "picked" image and show the AiImage frame
/// without a network round-trip.
final Uint8List sampleImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgAAIAAAUAAen6'
  '3NgAAAAASUVORK5CYII=',
);

/// Models offered by the demo's model selector.
const List<AiModelOption> demoModels = [
  AiModelOption(id: 'gpt-4o', label: 'GPT-4o', description: 'Most capable'),
  AiModelOption(
    id: 'gpt-4o-mini',
    label: 'GPT-4o mini',
    description: 'Fast and economical',
  ),
  AiModelOption(id: 'claude', label: 'Claude', description: 'Great at writing'),
];

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
        name: 'response',
        title: 'AiResponse — Markdown',
        child: const AiResponse(
          text: '## Streaming\n\nFold the **event stream** with a reducer:\n\n'
              '- rebuild only changed messages\n'
              '- stays at `60fps`\n\n'
              'See the [docs](https://docs.flutter.dev/ai).',
        ),
      ),
      (
        name: 'chain_of_thought',
        title: 'AiChainOfThought',
        child: const AiChainOfThought(
          initiallyExpanded: true,
          steps: [
            AiThoughtStep(
              label: 'Search the web',
              detail: 'flutter stream tokens',
            ),
            AiThoughtStep(label: 'Read top results'),
            AiThoughtStep(label: 'Synthesize an answer', isActive: true),
          ],
        ),
      ),
      (
        name: 'task',
        title: 'AiTask',
        child: const AiTask(
          title: 'Refactor the controller',
          items: [
            AiTaskItem(
              label: 'Read use_chat_controller.dart',
              status: AiTaskStatus.complete,
            ),
            AiTaskItem(
              label: 'Extract _startStream()',
              status: AiTaskStatus.active,
            ),
            AiTaskItem(label: 'Update tests'),
          ],
        ),
      ),
      (
        name: 'inline_citation',
        title: 'AiInlineCitation',
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Backed by sources'),
            SizedBox(width: 6),
            AiInlineCitation(number: 1),
            SizedBox(width: 4),
            AiInlineCitation(number: 2),
          ],
        ),
      ),
      (
        name: 'branch',
        title: 'AiBranch — versions',
        child: const AiBranch(index: 1, total: 3),
      ),
      (
        name: 'image',
        title: 'AiImage',
        child: SizedBox(
          width: 200,
          child: AiImage(bytes: sampleImageBytes, aspectRatio: 16 / 9),
        ),
      ),
      (
        name: 'model_selector',
        title: 'AiModelSelector',
        child: AiModelSelector(
          models: demoModels,
          selectedId: 'gpt-4o',
          onSelected: (_) {},
        ),
      ),
      (
        name: 'confirmation',
        title: 'AiConfirmation',
        child: AiConfirmation(
          title: 'Send this email to the team?',
          description: 'Subject: "Weekend plan in Lisbon"',
          onConfirm: () {},
          onDeny: () {},
        ),
      ),
      (
        name: 'context_meter',
        title: 'AiContextMeter',
        child: const AiContextMeter(usedTokens: 8200, totalTokens: 128000),
      ),
      (
        name: 'shimmer',
        title: 'AiShimmer',
        child: const AiShimmer(),
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
        title: 'AiComposer — attach · model · voice',
        child: AiComposer(
          onSend: (_) {},
          onAttach: () {},
          onVoice: () {},
          modelSelector: AiModelSelector(
            models: demoModels,
            selectedId: 'gpt-4o',
            onSelected: (_) {},
          ),
        ),
      ),
      (
        name: 'composer_busy',
        title: 'AiComposer — streaming (Stop)',
        child: AiComposer(onSend: (_) {}, onStop: () {}, isBusy: true),
      ),
    ];

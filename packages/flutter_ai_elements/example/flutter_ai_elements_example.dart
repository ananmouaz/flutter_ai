// A complete chat screen built from flutter_ai_elements, driven by a fake
// provider that echoes the prompt back word by word.
//
// Run inside a Flutter app target; this file shows the wiring.
import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

void main() => runApp(const _ExampleApp());

/// Echoes the user's last message, streamed word by word.
class _EchoProvider implements LlmProvider {
  @override
  Stream<AiStreamEvent> send(
    AiConversation conversation, {
    List<ToolDefinition>? tools,
    AiRequestOptions? options,
  }) async* {
    const id = 'assistant';
    final prompt = conversation.lastMessage?.text ?? '';
    yield const MessageStarted(messageId: id, role: AiRole.assistant);
    for (final word in prompt.split(' ')) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      yield TextDelta(messageId: id, delta: '$word ');
    }
    yield const MessageFinished(messageId: id, reason: FinishReason.stop);
  }
}

class _ExampleApp extends StatefulWidget {
  const _ExampleApp();

  @override
  State<_ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<_ExampleApp> {
  late final UseChatController _controller =
      UseChatController(provider: _EchoProvider());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        extensions: [
          // A bespoke mobile skin layered on the mobile-first default.
          AiThemeExtension.fallback().copyWith(
            userBubbleColor: const Color(0xFF7C3AED),
            bubbleRadius: const BorderRadius.all(Radius.circular(24)),
          ),
        ],
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_ai_elements')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: AiChat(controller: _controller)),
              const Divider(height: 1),
              AiPromptInput(controller: _controller),
            ],
          ),
        ),
      ),
    );
  }
}

// A minimal chat UI bound to UseChatController via ListenableBuilder.
//
// The provider here echoes the user's text back one word at a time to simulate
// streaming. Swap in a real LlmProvider to talk to a model.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';

void main() => runApp(const _ExampleApp());

/// Echoes the user's last message back, streamed word by word.
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
      await Future<void>.delayed(const Duration(milliseconds: 60));
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
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    unawaited(_controller.sendText(text));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_ai_client')),
        body: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => ListView(
                  children: [
                    for (final message in _controller.messages)
                      ListTile(
                        title: Text(message.role.name),
                        subtitle: Text(message.text),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  // Swap Send for Stop while a response streams.
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => IconButton(
                      icon: Icon(
                        _controller.status.isBusy ? Icons.stop : Icons.send,
                      ),
                      onPressed:
                          _controller.status.isBusy ? _controller.stop : _send,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

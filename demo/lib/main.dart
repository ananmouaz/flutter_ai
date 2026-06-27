import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_demo/demo_data.dart';
import 'package:flutter_ai_demo/demo_provider.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

void main() => runApp(const FlutterAiDemoApp());

/// Root of the showcase app.
class FlutterAiDemoApp extends StatelessWidget {
  /// Creates the demo app.
  const FlutterAiDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_ai demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorSchemeSeed: const Color(0xFF0D0D0D),
        scaffoldBackgroundColor: Colors.white,
        // Suppress Material ripples for a calmer, platform-neutral feel.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        extensions: [demoTheme],
      ),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _tab = 0;
  final UseChatController _controller =
      UseChatController(provider: const DemoChatProvider());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
              child: Row(
                children: [
                  const Text(
                    'flutter_ai',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // New-chat button (Chat tab only).
                  if (_tab == 0)
                    IconButton(
                      icon: const Icon(Icons.edit_square),
                      color: const Color(0xFF0D0D0D),
                      tooltip: 'New chat',
                      onPressed: _controller.clear,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _tab,
              backgroundColor: const Color(0xFFF0F0F2),
              thumbColor: Colors.white,
              onValueChanged: (value) => setState(() => _tab = value ?? 0),
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Chat'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('Elements'),
                ),
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                ChatScreen(controller: _controller),
                const GalleryScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A live chat backed by a [UseChatController] (owned by the parent).
class ChatScreen extends StatelessWidget {
  /// Creates the chat screen bound to [controller].
  const ChatScreen({super.key, required this.controller});

  /// The chat controller driving the conversation.
  final UseChatController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Error banner reacts to controller state.
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (controller.status != ChatStatus.error) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AiErrorBanner(
                message: '${controller.error}',
                onRetry: () => unawaited(controller.regenerate()),
                onDismiss: controller.clear,
              ),
            );
          },
        ),
        Expanded(
          child: AiChat(
            controller: controller,
            messageBuilder: _buildMessage,
            emptyState: _emptyState(),
          ),
        ),
        SafeArea(top: false, child: AiPromptInput(controller: controller)),
      ],
    );
  }

  // Adds a ChatGPT-style Copy/Regenerate action row beneath finished answers.
  Widget _buildMessage(BuildContext context, AiMessage message) {
    final bubble = AiMessageBubble(message: message);
    if (message.role != AiRole.assistant ||
        message.status != AiMessageStatus.complete) {
      return bubble;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        AiMessageActions(
          message: message,
          onRegenerate: () => unawaited(controller.regenerate()),
        ),
      ],
    );
  }

  void _onSuggestion(String text) {
    if (text.startsWith('Review')) {
      unawaited(
        controller.sendText(
          'Can you review this file?',
          attachments: const [
            FilePart(mediaType: 'text/x-dart', name: 'use_chat_controller.dart'),
          ],
        ),
      );
    } else {
      unawaited(controller.sendText(text));
    }
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AiEmptyState(
              title: 'Ask me anything',
              subtitle: 'Powered by flutter_ai',
            ),
            AiSuggestions(
              suggestions: const [
                'How do I stream tokens in Flutter?',
                'Review this file',
                'Trigger an error',
              ],
              onSelected: _onSuggestion,
            ),
          ],
        ),
      );
}

/// A scrolling gallery of every element with sample data.
class GalleryScreen extends StatelessWidget {
  /// Creates the gallery screen.
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = galleryItems();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: Color(0xFFEEECF5)),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9893A8),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            item.child,
          ],
        );
      },
    );
  }
}

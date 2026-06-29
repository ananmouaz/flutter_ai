import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ai_demo/code_highlighter.dart';
import 'package:flutter_ai_demo/demo_data.dart';
import 'package:flutter_ai_demo/demo_provider.dart';
import 'package:flutter_ai_demo/demo_tools.dart';
import 'package:flutter_ai_demo/feature_sections.dart';
import 'package:flutter_ai_demo/live_demo.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:flutter_ai_provider_gemini/flutter_ai_provider_gemini.dart';
import 'package:url_launcher/url_launcher.dart';

/// Supply a real Gemini key to talk to live models:
///
///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
///
/// With no key, the scripted [DemoChatProvider] is used.
const String _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Whether the live session runs the native Gemini provider with Google Search
/// grounding (so answers come back with real source citations). Gemini doesn't
/// allow grounding + function tools in one request, so when this is on the demo
/// tools are not advertised.
const bool _useLiveGemini = _geminiKey != '';

/// The native Gemini provider with grounding enabled, or the scripted demo.
LlmProvider _buildProvider() {
  if (!_useLiveGemini) return const DemoChatProvider();
  return GeminiProvider(apiKey: _geminiKey, enableGrounding: true);
}

void main() => runApp(const FlutterAiDemoApp());

/// Root of the showcase app.
class FlutterAiDemoApp extends StatefulWidget {
  /// Creates the demo app.
  const FlutterAiDemoApp({super.key});

  @override
  State<FlutterAiDemoApp> createState() => _FlutterAiDemoAppState();
}

class _FlutterAiDemoAppState extends State<FlutterAiDemoApp> {
  ThemeMode _mode = ThemeMode.light;

  void _toggleTheme() => setState(
    () => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_ai demo',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorSchemeSeed: const Color(0xFF0D0D0D),
        scaffoldBackgroundColor: Colors.white,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        extensions: [AiThemeExtension.fallback()],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF8E8E96),
        scaffoldBackgroundColor: const Color(0xFF131316),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        extensions: [AiThemeExtension.dark()],
      ),
      home: _HomePage(
        onToggleTheme: _toggleTheme,
        isDark: _mode == ThemeMode.dark,
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({required this.onToggleTheme, required this.isDark});

  final VoidCallback onToggleTheme;
  final bool isDark;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  String _modelId = demoModels.first.id;
  final UseChatController _controller = UseChatController(
    provider: _buildProvider(),
  );
  late final ToolRunner _toolRunner = ToolRunner(_controller);

  @override
  void initState() {
    super.initState();
    // Advertise tools, except with live Gemini grounding (Gemini rejects tools +
    // googleSearch in one request — we showcase grounded citations instead).
    if (!_useLiveGemini) _controller.setTools(demoTools);
    _toolRunner.addListener(_onToolChange);
  }

  void _onToolChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _toolRunner.removeListener(_onToolChange);
    _toolRunner.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _selectModel(String id) {
    setState(() => _modelId = id);
    _controller.setOptions(AiRequestOptions(model: id));
  }

  void _openGallery() => unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Every element'),
            scrolledUnderElevation: 0,
          ),
          body: const SafeArea(child: GalleryScreen()),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // The whole page is one scroll: a hero (header + live chat) followed by the
    // feature sections. The hero chat lives in a fixed-height region because
    // AiChat owns its own scrollable transcript.
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= 900;
    final heroHeight = (media.size.height * 0.66).clamp(420.0, 620.0);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Centered(
                child: _HeroHeader(
                  isDark: widget.isDark,
                  modelId: _modelId,
                  onSelectModel: _selectModel,
                  onToggleTheme: widget.onToggleTheme,
                  onNewChat: _controller.clear,
                  onOpenGallery: _openGallery,
                ),
              ),
            ),
            // Hero: the live, scripted chat — the "I want this" moment.
            SliverToBoxAdapter(
              child: SizedBox(
                height: heroHeight,
                child: ChatScreen(
                  controller: _controller,
                  toolRunner: _toolRunner,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _Centered(
                child: FeatureSections(
                  isWide: isWide,
                  onOpenGallery: _openGallery,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centers its child at the package's reading width on wide screens, so prose
/// and demos don't run edge-to-edge on desktop/web.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxWidth = AiThemeExtension.of(context).maxContentWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// The tight hero header: brand wordmark + value prop + badges, with the theme
/// toggle, model selector, new-chat and gallery actions.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.isDark,
    required this.modelId,
    required this.onSelectModel,
    required this.onToggleTheme,
    required this.onNewChat,
    required this.onOpenGallery,
  });

  final bool isDark;
  final String modelId;
  final ValueChanged<String> onSelectModel;
  final VoidCallback onToggleTheme;
  final VoidCallback onNewChat;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final subdued = DefaultTextStyle.of(
      context,
    ).style.color?.withValues(alpha: 0.62);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row stays compact (glyph + wordmark + icon actions) so it never
          // overflows on a narrow phone; the model selector rides in the Wrap
          // below, which reflows freely at any width.
          Row(
            children: [
              const _BrandGlyph(size: 30),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'flutter_ai',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                tooltip: 'Toggle theme',
                onPressed: onToggleTheme,
              ),
              IconButton(
                icon: const Icon(Icons.edit_square),
                tooltip: 'New chat',
                onPressed: onNewChat,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The complete AI chat toolkit for Flutter — streaming, tools, '
            'generative UI, voice.',
            style: TextStyle(fontSize: 16, height: 1.4, color: subdued),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AiModelSelector(
                models: demoModels,
                selectedId: modelId,
                onSelected: onSelectModel,
              ),
              const _Badge(label: '9 packages'),
              const _Badge(label: 'pub.dev'),
              const _Badge(label: 'zero lock-in'),
              _GalleryButton(theme: theme, onTap: onOpenGallery),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// A small outlined badge chip used in the hero header.
class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

/// A pill button that opens the full element gallery.
class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.theme, required this.onTap});

  final AiThemeExtension theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.accentColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 14,
                color: theme.onAccentColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Every element',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.onAccentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A live chat backed by a [UseChatController] (owned by the parent).
class ChatScreen extends StatelessWidget {
  /// Creates the chat screen bound to [controller].
  const ChatScreen({
    super.key,
    required this.controller,
    required this.toolRunner,
  });

  /// The chat controller driving the conversation.
  final UseChatController controller;

  /// Runs model tool calls (auto-exec + confirmations).
  final ToolRunner toolRunner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Context-usage meter + error banner react to controller state.
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final messages = controller.messages.length;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  children: [
                    if (messages > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: AiContextMeter(
                          usedTokens: 1200 + messages * 850,
                          totalTokens: 128000,
                        ),
                      ),
                    if (controller.status == ChatStatus.error)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: AiErrorBanner(
                          message: '${controller.error}',
                          onRetry: () => unawaited(controller.regenerate()),
                          onDismiss: controller.clear,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        Expanded(
          child: AiChat(
            controller: controller,
            messageBuilder: _buildMessage,
            emptyState: _emptyState(),
            loadingBuilder: (_) =>
                const SizedBox(width: 220, child: AiShimmer()),
            // Center the conversation on tablets/desktop/web.
            maxContentWidth: 760,
          ),
        ),
        SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: AiPromptInput(
                controller: controller,
                onPickAttachment: _pickAttachment,
                onVoice: _onVoice,
                onLive: () => unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LiveDemoScreen(controller: controller),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Simulates picking an image from the library (no real picker plugin).
  Future<List<FilePart>> _pickAttachment() async => [
    FilePart(
      mediaType: 'image/png',
      bytes: sampleImageBytes,
      name: 'photo.png',
    ),
  ];

  // Simulates a spoken prompt arriving from the mic.
  void _onVoice() => unawaited(controller.sendText('Suggest a dinner recipe'));

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
      );

  /// Edits the user message that prompted [assistant]: prefills a dialog with
  /// its text and, on save, rewrites it and re-runs the turn.
  Future<void> _editPrecedingUserMessage(
    BuildContext context,
    AiMessage assistant,
  ) async {
    final msgs = controller.messages;
    final i = msgs.indexWhere((m) => m.id == assistant.id);
    final userIndex = i == -1
        ? -1
        : msgs.sublist(0, i).lastIndexWhere((m) => m.role == AiRole.user);
    if (userIndex == -1) return;
    final user = msgs[userIndex];
    final field = TextEditingController(text: user.text);
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: field, autofocus: true, maxLines: null),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    field.dispose();
    if (edited != null && edited.trim().isNotEmpty) {
      await controller.editMessage(user.id, edited.trim());
    }
  }

  // A tiny generative-UI catalog: an allowlist mapping each DataPart `dataType`
  // to the widget that renders it.
  AiWidgetRegistry get _genUi => AiWidgetRegistry()
    ..register(
      'chain_of_thought',
      (context, data) =>
          AiChainOfThought(initiallyExpanded: true, steps: _steps(data)),
    )
    ..register(
      'task',
      (context, data) => AiTask(
        title: data['title'] as String? ?? 'Task',
        items: _taskItems(data),
      ),
    )
    ..register(
      'confirmation',
      (context, data) => AiConfirmation(
        title: data['title'] as String? ?? 'Confirm?',
        description: data['description'] as String?,
        onConfirm: () => _snack(context, 'Done.'),
        onDeny: () => _snack(context, 'Cancelled.'),
      ),
    );

  Widget _buildMessage(BuildContext context, AiMessage message) {
    if (message.role == AiRole.user) return AiMessageBubble(message: message);
    // Tool-result messages are folded into the assistant turn's tool cards.
    if (message.role == AiRole.tool) return const SizedBox.shrink();

    // Resolve tool results across the whole transcript: with real function
    // calling the result arrives in a separate tool message, not this one.
    final results = <String, ToolResultPart>{
      for (final m in controller.messages)
        for (final p in m.parts)
          if (p is ToolResultPart) p.toolCallId: p,
    };
    final sources = message.parts.whereType<SourcePart>().toList();
    final toolCalls = message.parts.whereType<ToolCallPart>().toList();
    final subdued = DefaultTextStyle.of(
      context,
    ).style.color?.withValues(alpha: 0.6);
    var toolsRendered = false;

    final children = <Widget>[];
    void add(Widget w) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 12));
      children.add(w);
    }

    // Assistant identity header (shows AiAvatar).
    add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AiAvatar(role: AiRole.assistant, size: 24),
          const SizedBox(width: 8),
          Text(
            'flutter_ai',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: subdued,
            ),
          ),
        ],
      ),
    );

    for (final part in message.parts) {
      switch (part) {
        case ReasoningPart(:final text):
          add(AiReasoning(text: text));
        case TextPart(:final text):
          // Smoothly reveal the streaming answer; show completed text as-is,
          // with syntax-highlighted code blocks.
          add(
            message.status == AiMessageStatus.streaming
                ? AiAnimatedResponse(text: text)
                : AiResponse(text: text, codeHighlighter: demoCodeHighlighter),
          );
        case ToolCallPart():
          // Render all tool calls once: a group when parallel, else a card.
          if (!toolsRendered) {
            toolsRendered = true;
            add(
              toolCalls.length > 1
                  ? AiToolGroup(calls: toolCalls, results: results)
                  : AiToolInvocation(
                      call: part,
                      result: results[part.toolCallId],
                    ),
            );
          }
        case ToolResultPart():
          break;
        case FilePart():
          if (part.mediaType.startsWith('image/')) {
            add(
              SizedBox(
                width: 260,
                child: AiImage(
                  url: part.url,
                  bytes: part.bytes,
                  aspectRatio: 16 / 9,
                ),
              ),
            );
          } else {
            add(AiAttachment(file: part));
          }
        case SourcePart():
          break; // rendered below
        case DataPart():
          // Generative UI via an allowlist registry: the model emits a DataPart
          // and the registered builder renders the matching widget.
          add(AiDataView(part: part, registry: _genUi));
      }
    }

    // Real tool calls awaiting approval (e.g. book_hotel) get a confirm card.
    for (final call in toolCalls) {
      final pending = toolRunner.pending[call.toolCallId];
      if (pending == null) continue;
      final info = toolRunner.confirmationFor(pending);
      add(
        AiConfirmation(
          title: info.title,
          description: info.description,
          onConfirm: () =>
              toolRunner.resolveConfirmation(call.toolCallId, approved: true),
          onDeny: () =>
              toolRunner.resolveConfirmation(call.toolCallId, approved: false),
        ),
      );
    }

    if (sources.isNotEmpty) {
      // A compact, collapsible strip of where the answer came from. (Grounded
      // answers can return dozens of sources, so AiSources caps them.) Tapping
      // a chip opens its URL; Gemini grounding URLs are Google redirects that
      // forward to the publisher page.
      add(
        AiSources(
          sources: sources,
          onTap: (source) => unawaited(
            launchUrl(source.url, mode: LaunchMode.externalApplication),
          ),
        ),
      );
    }

    if (message.status == AiMessageStatus.complete) {
      add(
        Row(
          children: [
            AiMessageActions(
              message: message,
              onGood: () => _snack(context, 'Thanks for the feedback!'),
              onBad: () => _snack(context, 'Thanks — we\'ll do better.'),
              onShare: () => _snack(context, 'Share sheet would open here.'),
              onRegenerate: () => unawaited(controller.regenerate()),
              onEdit: () =>
                  unawaited(_editPrecedingUserMessage(context, message)),
            ),
            const Spacer(),
            // Real regeneration history: only the latest turn has branches.
            if (message == controller.messages.last &&
                controller.branchCount > 1)
              AiBranch(
                index: controller.branchIndex,
                total: controller.branchCount,
                onPrevious: () =>
                    controller.selectBranch(controller.branchIndex - 1),
                onNext: () =>
                    controller.selectBranch(controller.branchIndex + 1),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  List<AiThoughtStep> _steps(Map<String, Object?> data) {
    final raw = (data['steps'] as List?) ?? const [];
    return raw.map((s) {
      final m = (s! as Map).cast<String, Object?>();
      return AiThoughtStep(
        label: m['label'] as String? ?? '',
        detail: m['detail'] as String?,
        isActive: m['active'] as bool? ?? false,
      );
    }).toList();
  }

  List<AiTaskItem> _taskItems(Map<String, Object?> data) {
    final raw = (data['items'] as List?) ?? const [];
    return raw.map((item) {
      final m = (item! as Map).cast<String, Object?>();
      return AiTaskItem(
        label: m['label'] as String? ?? '',
        status: switch (m['status']) {
          'complete' => AiTaskStatus.complete,
          'active' => AiTaskStatus.active,
          'error' => AiTaskStatus.error,
          _ => AiTaskStatus.pending,
        },
      );
    }).toList();
  }

  void _onSuggestion(String text) {
    if (text.startsWith('Summarize')) {
      unawaited(
        controller.sendText(
          'Summarize this article',
          attachments: const [
            FilePart(mediaType: 'application/pdf', name: 'article.pdf'),
          ],
        ),
      );
    } else {
      unawaited(controller.sendText(text));
    }
  }

  // The hero chat's empty state uses the built-in AiEmptyState, now with a
  // brand [glyph] and tappable conversation-starter [suggestions] that seed the
  // first turn — the modern-assistant onboarding pattern, in one widget.
  Widget _emptyState() => AiEmptyState(
    glyph: const _BrandGlyph(size: 56),
    title: 'Ask me anything',
    subtitle: 'A live, scripted demo — no API key required.',
    suggestions: const [
      'Plan a weekend in Lisbon',
      'Suggest a dinner recipe',
      'How do I center a widget?',
      'Summarize this article',
    ],
    onSuggestionTap: _onSuggestion,
  );
}

/// The `flutter_ai` brand glyph — a luminous accent square with a soft glow,
/// reused in the empty state and the hero header so the showcase feels branded.
class _BrandGlyph extends StatelessWidget {
  const _BrandGlyph({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.orbColor,
            Color.lerp(theme.orbColor, theme.accentColor, 0.5)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.orbColor.withValues(alpha: 0.35),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.02,
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome,
        size: size * 0.5,
        color: theme.onAccentColor,
      ),
    );
  }
}

/// A scrolling gallery of every element with sample data.
class GalleryScreen extends StatelessWidget {
  /// Creates the gallery screen.
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = galleryItems();
    final divider = AiThemeExtension.of(context).borderColor;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, color: divider),
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

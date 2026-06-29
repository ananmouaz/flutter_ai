import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ai_demo/code_highlighter.dart';
import 'package:flutter_ai_demo/live_demo.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:url_launcher/url_launcher.dart';

/// The scrollable marketing feature sections shown beneath the hero chat.
///
/// Each section is a short title + one-line blurb + a *live* mini-demo built
/// from the real `flutter_ai_elements` widgets and scripted data — so the page
/// doubles as a guided tour of the package's surface, including its newest
/// widgets (`AiOrb`, the `glyph`/`suggestions` empty state, danger-tone
/// `AiConfirmation`, favicon `AiSources`, the new theme tokens).
class FeatureSections extends StatelessWidget {
  /// Creates the feature sections.
  const FeatureSections({
    super.key,
    required this.isWide,
    required this.onOpenGallery,
  });

  /// Whether the viewport is wide enough to lay demos out side-by-side.
  final bool isWide;

  /// Opens the full element gallery.
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionDivider(),
          const _Section(
            title: 'Streaming & Markdown',
            blurb:
                'Tokens stream in with a blur fade-in, then settle into rich '
                'Markdown — headings, code, lists, quotes and links.',
            child: _StreamingDemo(),
          ),
          const _Section(
            title: 'Generative UI',
            blurb:
                'The model emits typed data parts; an allowlist registry maps '
                'each to a real widget — thoughts, tasks, confirmations.',
            child: _GenerativeUiDemo(),
          ),
          const _Section(
            title: 'Tool calling',
            blurb:
                'Inspect what the agent did. Parallel calls group together '
                'with arguments and results — never hidden.',
            child: _ToolCallingDemo(),
          ),
          _Section(
            title: 'Citations & grounding',
            blurb:
                'Show where answers came from. Source chips carry favicons, '
                'index badges and hover — tap to open.',
            child: const _CitationsDemo(),
          ),
          _Section(
            title: 'Voice',
            blurb:
                'A calm, animated AiOrb and a full-screen live voice session, '
                'engine-agnostic and themeable.',
            child: _VoiceDemo(onOpenLive: () => _openLive(context)),
          ),
          _Section(
            title: 'Theming',
            blurb:
                'One AiThemeExtension restyles everything. Here is the same '
                'answer in light and dark, side by side.',
            child: _ThemingDemo(isWide: isWide),
          ),
          _Section(
            title: 'Every element',
            blurb:
                'Thirty-plus composable widgets, each themeable and testable. '
                'Browse the full gallery with sample data.',
            child: _GalleryCta(onOpenGallery: onOpenGallery),
          ),
        ],
      ),
    );
  }

  void _openLive(BuildContext context) => unawaited(
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LiveDemoScreen())),
  );
}

/// A single feature section: title, blurb, and a live demo card.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.blurb,
    required this.child,
  });

  final String title;
  final String blurb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            blurb,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: color?.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 16),
          _DemoCard(child: child),
          const _SectionDivider(),
        ],
      ),
    );
  }
}

/// A bordered surface that frames a live mini-demo.
class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.borderColor),
      ),
      child: child,
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Divider(height: 1, color: AiThemeExtension.of(context).borderColor),
  );
}

// ---- Streaming & Markdown --------------------------------------------------

/// Renders rich Markdown through [AiResponse] with syntax-highlighted code,
/// then re-runs the streaming reveal (`AiAnimatedResponse`) on demand so the
/// blur-fade is visible without an API key.
class _StreamingDemo extends StatefulWidget {
  const _StreamingDemo();

  @override
  State<_StreamingDemo> createState() => _StreamingDemoState();
}

class _StreamingDemoState extends State<_StreamingDemo> {
  static const String _markdown =
      '## Streaming, done right\n\n'
      'Fold the **event stream** with a reducer so only the *changed* '
      'message rebuilds:\n\n'
      '```dart\n'
      'stream.listen((event) {\n'
      '  state = reduce(state, event);\n'
      '});\n'
      '```\n\n'
      '- Stays at `60fps` while tokens arrive\n\n'
      'What ships:\n\n'
      '- [x] Streaming Markdown\n'
      '- [x] Tool calls\n'
      '- [ ] Your idea here\n\n'
      '> Trust comes from showing the work.\n\n'
      'See the [docs](https://docs.flutter.dev).';

  // A nonce changes the key so AiAnimatedResponse restarts its reveal.
  int _nonce = 0;
  bool _streaming = false;

  void _replay() {
    setState(() {
      _streaming = true;
      _nonce++;
    });
    // Let the reveal play, then settle to the full Markdown render.
    Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _streaming = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_streaming)
          AiAnimatedResponse(key: ValueKey(_nonce), text: _markdown)
        else
          const AiResponse(
            text: _markdown,
            codeHighlighter: demoCodeHighlighter,
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _GhostButton(
            icon: Icons.play_arrow_rounded,
            label: _streaming ? 'Streaming…' : 'Replay streaming',
            onTap: _streaming ? null : _replay,
          ),
        ),
      ],
    );
  }
}

// ---- Generative UI ---------------------------------------------------------

/// Drives a tiny generative-UI catalog: each [DataPart] dataType resolves to a
/// real widget via [AiWidgetRegistry] — including a danger-tone
/// [AiConfirmation].
class _GenerativeUiDemo extends StatelessWidget {
  const _GenerativeUiDemo();

  static final AiWidgetRegistry _registry = AiWidgetRegistry()
    ..register(
      'chain_of_thought',
      (context, data) => const AiChainOfThought(
        initiallyExpanded: true,
        steps: [
          AiThoughtStep(label: 'Read the request'),
          AiThoughtStep(label: 'Draft the email'),
          AiThoughtStep(label: 'Await approval', isActive: true),
        ],
      ),
    )
    ..register(
      'task',
      (context, data) => const AiTask(
        title: 'Send weekly digest',
        items: [
          AiTaskItem(label: 'Gather metrics', status: AiTaskStatus.complete),
          AiTaskItem(label: 'Compose email', status: AiTaskStatus.active),
          AiTaskItem(label: 'Send to list', status: AiTaskStatus.pending),
        ],
      ),
    )
    ..register(
      'confirmation',
      (context, data) => AiConfirmation(
        tone: AiConfirmationTone.danger,
        icon: Icons.delete_outline,
        title: 'Delete all 1,284 archived records?',
        description: 'This cannot be undone.',
        confirmLabel: 'Delete',
        onConfirm: () {},
        onDeny: () {},
      ),
    );

  static const List<DataPart> _parts = [
    DataPart(dataType: 'chain_of_thought', data: {}),
    DataPart(dataType: 'task', data: {}),
    DataPart(dataType: 'confirmation', data: {}),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final part in _parts) ...[
          AiDataView(part: part, registry: _registry),
          if (part != _parts.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ---- Tool calling ----------------------------------------------------------

/// Shows a parallel tool call rendered with [AiToolGroup]: two calls, one
/// resolved with a result, one still executing.
class _ToolCallingDemo extends StatelessWidget {
  const _ToolCallingDemo();

  @override
  Widget build(BuildContext context) {
    return const AiToolGroup(
      calls: [
        ToolCallPart(
          toolCallId: 'c1',
          toolName: 'get_weather',
          args: {'city': 'Lisbon'},
          state: ToolCallState.outputAvailable,
        ),
        ToolCallPart(
          toolCallId: 'c2',
          toolName: 'find_hotels',
          args: {'city': 'Lisbon', 'nights': 2},
          state: ToolCallState.executing,
        ),
      ],
      results: {
        'c1': ToolResultPart(
          toolCallId: 'c1',
          result: {'tempC': 24, 'condition': 'Sunny'},
        ),
      },
    );
  }
}

// ---- Citations & grounding -------------------------------------------------

/// A few real-looking sources rendered with favicons enabled, plus a sentence
/// carrying inline [AiInlineCitation] badges.
class _CitationsDemo extends StatelessWidget {
  const _CitationsDemo();

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 15.5, height: 1.5, color: color),
            children: const [
              TextSpan(text: 'Lisbon is sunny, about 24°C this weekend '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AiInlineCitation(number: 1),
              ),
              TextSpan(text: ' with a Sintra day trip recommended '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: AiInlineCitation(number: 2),
              ),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AiSources(
          showFavicons: true,
          sources: [
            SourcePart(
              url: Uri.parse('https://www.timeout.com/lisbon'),
              title: 'timeout.com',
            ),
            SourcePart(
              url: Uri.parse('https://www.lonelyplanet.com/portugal/lisbon'),
              title: 'lonelyplanet.com',
            ),
            SourcePart(
              url: Uri.parse('https://flutter.dev'),
              title: 'flutter.dev',
            ),
          ],
          onTap: (source) => unawaited(
            launchUrl(source.url, mode: LaunchMode.externalApplication),
          ),
        ),
      ],
    );
  }
}

// ---- Voice -----------------------------------------------------------------

/// A live, breathing [AiOrb] beside a teaser that opens the full-screen
/// [LiveDemoScreen] voice session.
class _VoiceDemo extends StatelessWidget {
  const _VoiceDemo({required this.onOpenLive});

  final VoidCallback onOpenLive;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Row(
      children: [
        const AiOrb(size: 72, amplitude: 0.4),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Talk to it',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'A full-screen live session with streaming transcripts.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: color?.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 12),
              _GhostButton(
                icon: Icons.graphic_eq_rounded,
                label: 'Open live session',
                onTap: onOpenLive,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Theming ---------------------------------------------------------------

/// The same answer rendered through both [AiThemeExtension.fallback] (light)
/// and [AiThemeExtension.dark], to show that one token set restyles everything.
class _ThemingDemo extends StatelessWidget {
  const _ThemingDemo({required this.isWide});

  final bool isWide;

  static const String _md =
      '## Day 1\n- Belém Tower & pastéis de nata\n- Alfama and the castle\n\n'
      'Sunny, **~24°C** — pack light.';

  @override
  Widget build(BuildContext context) {
    final light = _Themed(
      label: 'Light',
      brightness: Brightness.light,
      extension: AiThemeExtension.fallback(),
      background: Colors.white,
    );
    final dark = _Themed(
      label: 'Dark',
      brightness: Brightness.dark,
      extension: AiThemeExtension.dark(),
      background: const Color(0xFF131316),
    );
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: light),
          const SizedBox(width: 12),
          Expanded(child: dark),
        ],
      );
    }
    return Column(children: [light, const SizedBox(height: 12), dark]);
  }
}

/// A small message preview wrapped in its own [Theme] so the [extension] and
/// brightness apply only to this subtree.
class _Themed extends StatelessWidget {
  const _Themed({
    required this.label,
    required this.brightness,
    required this.extension,
    required this.background,
  });

  final String label;
  final Brightness brightness;
  final AiThemeExtension extension;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: brightness,
        extensions: [extension],
      ),
      child: Builder(
        builder: (context) {
          final fg = brightness == Brightness.dark
              ? const Color(0xFFECECEC)
              : const Color(0xFF0D0D0D);
          return DefaultTextStyle.merge(
            style: TextStyle(color: fg),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: extension.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg.withValues(alpha: 0.5),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const AiMessageBubble(
                    message: AiMessage(
                      id: 'u',
                      role: AiRole.user,
                      parts: [TextPart('Plan a weekend in Lisbon')],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AiResponse(text: _ThemingDemo._md),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---- Gallery CTA -----------------------------------------------------------

class _GalleryCta extends StatelessWidget {
  const _GalleryCta({required this.onOpenGallery});

  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _GhostButton(
        icon: Icons.grid_view_rounded,
        label: 'Browse the full gallery',
        onTap: onOpenGallery,
      ),
    );
  }
}

// ---- Shared ----------------------------------------------------------------

/// A bordered, low-emphasis action button used across the sections.
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    return Material(
      color: theme.assistantBubbleColor,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

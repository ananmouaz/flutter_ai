import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';

/// Human-readable step text for a tool call. Production apps map their own
/// tool names; raw names and arguments stay behind "Show tool details".
String _label(ToolCallPart call, {required bool done}) {
  final args = call.args;
  return switch (call.toolName) {
    'search_web' => done ? 'Searched the web' : 'Searching the web',
    'read_page' =>
      done
          ? 'Read ${Uri.tryParse('${args['url']}')?.host ?? 'a page'}'
          : 'Reading ${Uri.tryParse('${args['url']}')?.host ?? 'a page'}',
    'compare_fares' => done ? 'Compared fares' : 'Comparing fares',
    'flight_status' =>
      done
          ? 'Checked flight ${args['flight'] ?? ''}'.trim()
          : 'Checking flight ${args['flight'] ?? ''}'.trim(),
    'check_calendar' =>
      done ? 'Checked your calendar' : 'Checking your calendar',
    'search_restaurants' => done ? 'Found a table' : 'Finding a table',
    'book_table' => done ? 'Booked the table' : 'Waiting for your approval',
    final name => name,
  };
}

/// Maps one tool call to a checklist step.
///
/// A call without a result is active only while its run is still going; once
/// the run failed or was stopped it is an error or simply not done. Status is
/// derived from tool and message state only — never from model reasoning.
AiTaskItem runStepFor(
  ToolCallPart call,
  ToolResultPart? result, {
  required bool running,
  required bool failed,
}) {
  if (result != null) {
    return AiTaskItem(
      label: result.isError
          ? '${_label(call, done: false)} · not completed'
          : _label(call, done: true),
      status: result.isError ? AiTaskStatus.error : AiTaskStatus.complete,
    );
  }
  if (running) {
    return AiTaskItem(
      label: _label(call, done: false),
      status: AiTaskStatus.active,
    );
  }
  return AiTaskItem(
    label: _label(call, done: false),
    status: failed ? AiTaskStatus.error : AiTaskStatus.pending,
  );
}

/// A compact, expandable summary of an agent run ("3 steps completed"),
/// composed from [AiTask]. Collapsed by default so the answer stays first.
class RunSummary extends StatelessWidget {
  /// Creates a run summary for [steps].
  const RunSummary({super.key, required this.steps});

  /// One item per tool call, in order.
  final List<AiTaskItem> steps;

  @override
  Widget build(BuildContext context) {
    final active = steps.where((s) => s.status == AiTaskStatus.active);
    final failed = steps.any((s) => s.status == AiTaskStatus.error);
    final done = steps.where((s) => s.status == AiTaskStatus.complete).length;
    final title = active.isNotEmpty
        ? active.first.label
        : done == steps.length
        ? '$done ${done == 1 ? 'step' : 'steps'} completed'
        : failed
        ? "Couldn't finish"
        : 'Stopped';
    return Semantics(
      liveRegion: active.isEmpty,
      child: AiTask(title: title, items: steps, initiallyExpanded: false),
    );
  }
}

/// A compact "N sources" control that opens [showSourcesSheet].
class SourcesButton extends StatelessWidget {
  /// Creates the button.
  const SourcesButton({super.key, required this.count, required this.onTap});

  /// Number of sources.
  final int count;

  /// Opens the sheet.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final label = '$count ${count == 1 ? 'source' : 'sources'}';
    return Semantics(
      button: true,
      label: 'Show $label',
      excludeSemantics: true,
      child: Material(
        color: theme.effectiveChipColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link_rounded,
                    size: 16,
                    color: theme.assistantTextColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.assistantTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a bottom sheet listing [sources] with their titles and hosts.
Future<void> showSourcesSheet(
  BuildContext context,
  List<SourcePart> sources, {
  required void Function(SourcePart source) onOpen,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.5,
    maxChildSize: 0.9,
    builder: (context, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Semantics(
            header: true,
            child: Text(
              'Sources',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        for (var i = 0; i < sources.length; i++)
          ListTile(
            leading: CircleAvatar(
              radius: 14,
              child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
            ),
            title: Text(sources[i].title ?? sources[i].url.host),
            subtitle: Text(sources[i].url.host),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => onOpen(sources[i]),
          ),
      ],
    ),
  ),
);

/// Reads question options from a `question` data part.
List<AiQuestionOption> questionOptionsFrom(Map<String, Object?> data) => [
  for (final raw in (data['options'] as List? ?? const []))
    if (raw is Map)
      AiQuestionOption(value: '${raw['value']}', label: '${raw['label']}'),
];

/// An action on a [ResultCard].
enum ResultCardAction {
  /// Accept the generated item.
  add,

  /// Revise it in the composer.
  edit,

  /// Throw it away.
  discard,
}

/// The host-owned outcome of a [ResultCard].
enum ResultCardDecision {
  /// The item was added.
  added,

  /// The item was discarded.
  discarded,
}

/// A structured result the agent produced, with explicit actions and a
/// settled state once the host has acted on it.
class ResultCard extends StatelessWidget {
  /// Creates the card.
  const ResultCard({
    super.key,
    required this.title,
    this.when,
    this.detail,
    this.decision,
    this.onAction,
  });

  /// The item headline.
  final String title;

  /// When it happens.
  final String? when;

  /// Supporting text.
  final String? detail;

  /// The settled outcome, or null while the user can still act.
  final ResultCardDecision? decision;

  /// Reports an action; null makes the buttons inert (e.g. while streaming).
  final ValueChanged<ResultCardAction>? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final color = DefaultTextStyle.of(context).style.color;
    final muted = color?.withValues(alpha: 0.65);
    VoidCallback? act(ResultCardAction a) =>
        onAction == null ? null : () => onAction!(a);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.event_available_rounded, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (when != null)
                      Text(when!, style: TextStyle(color: muted)),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(detail!, style: TextStyle(color: muted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (decision != null)
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    decision == ResultCardDecision.added
                        ? Icons.check_circle_rounded
                        : Icons.delete_outline_rounded,
                    size: 18,
                    color: decision == ResultCardDecision.added
                        ? theme.successColor
                        : muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      decision == ResultCardDecision.added
                          ? 'Added to your reminders'
                          : 'Discarded',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: theme.onAccentColor,
                  ),
                  onPressed: act(ResultCardAction.add),
                  child: const Text('Add'),
                ),
                OutlinedButton(
                  onPressed: act(ResultCardAction.edit),
                  child: const Text('Edit'),
                ),
                TextButton(
                  onPressed: act(ResultCardAction.discard),
                  child: const Text('Discard'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The conversation header: page-colored, a small centered title and soft
/// circular actions, so the transcript — not the chrome — carries the screen.
class ChatHeader extends StatelessWidget {
  /// Creates the header.
  const ChatHeader({
    super.key,
    required this.title,
    required this.onNewChat,
    required this.showToolDetails,
    required this.onToggleToolDetails,
  });

  /// The conversation title ("New chat" before the first message).
  final String title;

  /// Starts a fresh conversation.
  final VoidCallback onNewChat;

  /// Whether raw tool calls are shown under each run summary.
  final bool showToolDetails;

  /// Toggles [showToolDetails].
  final VoidCallback onToggleToolDetails;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    final canPop = Navigator.of(context).canPop();
    // Leading and trailing take the same width so the title stays centered.
    const sideWidth = 2 * 40.0 + 8;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              SizedBox(
                width: sideWidth,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: canPop
                      ? CircleIconButton(
                          icon: Icons.adaptive.arrow_back_rounded,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onTap: () => Navigator.of(context).maybePop(),
                        )
                      : null,
                ),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: color,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: sideWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleIconButton(
                      icon: Icons.edit_square,
                      tooltip: 'New chat',
                      onTap: onNewChat,
                    ),
                    const SizedBox(width: 8),
                    MenuAnchor(
                      alignmentOffset: const Offset(-120, 6),
                      menuChildren: [
                        CheckboxMenuButton(
                          value: showToolDetails,
                          onChanged: (_) => onToggleToolDetails(),
                          child: const Text('Show tool details'),
                        ),
                      ],
                      builder: (context, menu, _) => CircleIconButton(
                        icon: Icons.more_horiz_rounded,
                        tooltip: 'More',
                        onTap: () => menu.isOpen ? menu.close() : menu.open(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 40 pt circular icon button with a soft fill, as in modern assistant
/// headers.
class CircleIconButton extends StatelessWidget {
  /// Creates the button.
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  /// The glyph.
  final IconData icon;

  /// Tooltip and accessible label.
  final String tooltip;

  /// Called on tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: theme.effectiveChipColor,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 40,
              child: Icon(icon, size: 19, color: theme.assistantTextColor),
            ),
          ),
        ),
      ),
    );
  }
}

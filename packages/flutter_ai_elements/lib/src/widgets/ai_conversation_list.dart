import 'package:flutter/material.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// A ChatGPT-style conversation list / sidebar: a "New chat" action above a
/// scrollable list of [ChatThread]s, with select and (optional) delete.
///
/// Presentational — drive it from a [ChatThreadStore]: pass [threads],
/// [selectedId], and wire [onSelect] / [onNew] / [onDelete] to your store and
/// controller.
class AiConversationList extends StatelessWidget {
  /// Creates a conversation list.
  const AiConversationList({
    super.key,
    required this.threads,
    this.selectedId,
    this.onSelect,
    this.onNew,
    this.onDelete,
    this.newChatLabel,
    this.header,
    this.footer,
    this.trailingBuilder,
  });

  /// The threads to show, in display order (typically newest first).
  final List<ChatThread> threads;

  /// The id of the currently open thread, highlighted in the list.
  final String? selectedId;

  /// Called when a thread is tapped.
  final void Function(ChatThread thread)? onSelect;

  /// Called when the "New chat" action is tapped. Hidden when null.
  final VoidCallback? onNew;

  /// Called when a thread's delete affordance is tapped. Hidden when null.
  final void Function(ChatThread thread)? onDelete;

  /// Label for the new-chat action. Defaults to the localized "New chat".
  final String? newChatLabel;

  /// Optional content pinned above the new-chat action and thread list — e.g. a
  /// brand wordmark, a close button, or fixed nav entries (Images/Library/…).
  final Widget? header;

  /// Optional content pinned below the thread list — e.g. an account footer
  /// (avatar · name · settings).
  final Widget? footer;

  /// Per-thread trailing widget (e.g. a pin glyph + overflow menu). When
  /// provided it replaces the default delete affordance, so wire delete/pin
  /// yourself. Return null for no trailing on a given thread.
  final Widget? Function(BuildContext context, ChatThread thread)?
      trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    final l = AiLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        if (onNew != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add, size: 18),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(newChatLabel ?? l.newChat),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: threads.length,
            itemBuilder: (context, i) {
              final thread = threads[i];
              final selected = thread.id == selectedId;
              return Material(
                color: selected ? theme.effectiveChipColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: true,
                  selected: selected,
                  title: Text(
                    thread.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: onSelect == null ? null : () => onSelect!(thread),
                  trailing: trailingBuilder != null
                      ? trailingBuilder!(context, thread)
                      : onDelete == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: l.delete,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onDelete!(thread),
                            ),
                ),
              );
            },
          ),
        ),
        if (footer != null) footer!,
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_ai_client/flutter_ai_client.dart';
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
    this.newChatLabel = 'New chat',
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

  /// Label for the new-chat action.
  final String newChatLabel;

  @override
  Widget build(BuildContext context) {
    final theme = AiThemeExtension.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onNew != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add, size: 18),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(newChatLabel),
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
                color:
                    selected ? theme.assistantBubbleColor : Colors.transparent,
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
                  trailing: onDelete == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onDelete!(thread),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

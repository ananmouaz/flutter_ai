import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ai_demo/production/production_provider.dart';
import 'package:flutter_ai_demo/production/production_widgets.dart';
import 'package:flutter_ai_elements/flutter_ai_elements.dart';
import 'package:url_launcher/url_launcher.dart';

/// Starter prompts shown in the empty conversation's grid.
const productionStarters = [
  'Compare weekend trains to Porto',
  'Remind me to renew my passport',
  'Book a table for two tonight',
  'Check flight TP 1350',
];

/// A minimal production conversation built only from existing elements.
///
/// It puts the answer, the current task state and the next action first:
/// a compact run summary built from real tool-call state (never from private
/// model reasoning), the answer, a source count that opens a details sheet,
/// and full-width follow-ups. Diagnostics (raw tool arguments and results) sit
/// behind the overflow menu. Approval execution and persistence stay with the
/// host: the card only reports the user's decision.
class ProductionChatScreen extends StatefulWidget {
  /// Creates the recipe screen. Pass a [provider] to replace the script.
  const ProductionChatScreen({super.key, this.provider});

  /// The agent backend; defaults to [ProductionAgentProvider].
  final LlmProvider? provider;

  @override
  State<ProductionChatScreen> createState() => _ProductionChatScreenState();
}

class _ProductionChatScreenState extends State<ProductionChatScreen> {
  late final UseChatController _chat = UseChatController(
    provider: widget.provider ?? ProductionAgentProvider(),
    onToolCalls: _runTools,
  );
  final TextEditingController _draft = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  late final AiWidgetRegistry _registry = AiWidgetRegistry()
    ..register('question', _question)
    ..register('result_card', _resultCard);

  // Host-owned state. A real app persists these with the conversation so they
  // survive lazy-list eviction and restarts; here they live for the screen.
  final Map<String, Completer<bool>> _approvalWaits = {};
  final Map<String, AiConfirmationStatus> _approvalStatus = {};
  final Map<AiPartRef, AiQuestionResponse> _answers = {};
  final Map<AiPartRef, ResultCardDecision> _cardDecisions = {};
  bool _showToolDetails = false;

  @override
  void dispose() {
    _chat.dispose();
    _draft.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  /// The engine's tool executor. Research tools already ran on the "server"
  /// (their results streamed in), so only the booking reaches the app, and it
  /// runs only after an explicit Allow. Stop or a new message cancels the wait.
  Future<List<ToolResultPart>> _runTools(
    List<ToolCallPart> calls,
    AiToolCallSignal signal,
  ) async {
    final results = <ToolResultPart>[];
    for (final call in calls) {
      if (call.toolName != bookTableTool) {
        results.add(
          ToolResultPart(
            toolCallId: call.toolCallId,
            result: 'Unknown tool ${call.toolName}',
            isError: true,
          ),
        );
        continue;
      }
      final id = call.toolCallId;
      final wait = _approvalWaits[id] = Completer<bool>();
      _setApproval(id, AiConfirmationStatus.awaiting);
      final approved = await Future.any<bool?>([
        wait.future,
        signal.whenCancelled.then((_) => null),
      ]);
      _approvalWaits.remove(id);
      if (approved == null) {
        _setApproval(id, AiConfirmationStatus.expired);
        return const [];
      }
      _setApproval(id, AiConfirmationStatus.submitting);
      // A real host calls its backend here, with an idempotency key.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (signal.isCancelled) {
        _setApproval(id, AiConfirmationStatus.expired);
        return const [];
      }
      // From here the transcript's tool result is the source of truth.
      _setApproval(id, null);
      results.add(
        approved
            ? ToolResultPart(
                toolCallId: id,
                result: {'status': 'booked', 'confirmation': 'TR-2041'},
              )
            : ToolResultPart(
                toolCallId: id,
                result: {'status': 'declined'},
                isError: true,
              ),
      );
    }
    return results;
  }

  void _setApproval(String id, AiConfirmationStatus? status) {
    if (!mounted) return;
    setState(() {
      if (status == null) {
        _approvalStatus.remove(id);
      } else {
        _approvalStatus[id] = status;
      }
    });
  }

  Map<String, ToolResultPart> get _results => {
    for (final m in _chat.messages)
      for (final p in m.parts)
        if (p is ToolResultPart) p.toolCallId: p,
  };

  AiConfirmationStatus _approvalFor(ToolCallPart call, ToolResultPart? result) {
    if (result != null) {
      if (!result.isError) return AiConfirmationStatus.approved;
      final cancelled =
          result.result is String &&
          (result.result! as String).startsWith('Cancelled');
      return cancelled
          ? AiConfirmationStatus.expired
          : AiConfirmationStatus.denied;
    }
    // Before the executor starts waiting, the card shows inert buttons.
    return _approvalStatus[call.toolCallId] ??
        (_chat.status.isBusy
            ? AiConfirmationStatus.awaiting
            : AiConfirmationStatus.expired);
  }

  void _send(String text) => unawaited(_chat.sendText(text));

  /// Names the conversation after its first question, like assistant apps do.
  String get _title {
    for (final m in _chat.messages) {
      if (m.role == AiRole.user && m.text.isNotEmpty) return m.text;
    }
    return 'New chat';
  }

  void _newChat() {
    _chat.clear();
    _draft.clear();
    setState(() {
      _answers.clear();
      _cardDecisions.clear();
    });
  }

  FutureOr<void> _onPartAction(AiPartRef ref, Object? value) async {
    if (value is AiQuestionResponse) {
      if (_answers.containsKey(ref)) return;
      // A real host stores the answer server-side before continuing.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted || _answers.containsKey(ref)) return;
      setState(() => _answers[ref] = value);
      final labels = _questionOptions(ref)
          .where((o) => value.selectedValues.contains(o.value))
          .map((o) => o.label.toLowerCase());
      _send(
        [
          'Remind me ${labels.join(' and ')}'.trim(),
          if (value.text.isNotEmpty) value.text,
        ].join('. '),
      );
    } else if (value is ResultCardAction) {
      switch (value) {
        case ResultCardAction.add:
          setState(() => _cardDecisions[ref] = ResultCardDecision.added);
        case ResultCardAction.discard:
          setState(() => _cardDecisions[ref] = ResultCardDecision.discarded);
        case ResultCardAction.edit:
          _draft
            ..text = 'Change the reminder to '
            ..selection = TextSelection.collapsed(offset: _draft.text.length);
          _composerFocus.requestFocus();
      }
    }
  }

  List<AiQuestionOption> _questionOptions(AiPartRef ref) {
    final part = _chat.conversation
        .messageById(ref.messageId)
        ?.parts[ref.partIndex];
    return part is DataPart ? questionOptionsFrom(part.data) : const [];
  }

  Widget _question(BuildContext context, Map<String, Object?> data) {
    final scope = AiPartScope.maybeOf(context)!;
    final action = scope.onAction;
    return AiQuestion(
      key: ValueKey(scope.ref),
      prompt: data['prompt'] as String? ?? 'Choose one',
      options: questionOptionsFrom(data),
      allowFreeform: true,
      answer: _answers[scope.ref],
      enabled: !_chat.status.isBusy,
      onSubmit: action == null ? null : (response) => action(response),
    );
  }

  Widget _resultCard(BuildContext context, Map<String, Object?> data) {
    final scope = AiPartScope.maybeOf(context)!;
    final action = scope.onAction;
    return ResultCard(
      title: data['title'] as String? ?? '',
      when: data['when'] as String?,
      detail: data['detail'] as String?,
      decision: _cardDecisions[scope.ref],
      onAction: action == null
          ? null
          : (value) => unawaited(Future<void>.sync(() => action(value))),
    );
  }

  Widget? _part(BuildContext context, AiPart part, AiMessage message) {
    if (part is SourcePart) return const SizedBox.shrink();
    if (part is DataPart && part.dataType == 'follow_ups') {
      return const SizedBox.shrink();
    }
    if (part is! ToolCallPart) return null;
    if (part.toolName != bookTableTool) return const SizedBox.shrink();
    final result = _results[part.toolCallId];
    final status = _approvalFor(part, result);
    final wait = _approvalWaits[part.toolCallId];
    final restaurant = part.args['restaurant'] as String? ?? 'the restaurant';
    final time = part.args['time'] as String? ?? '';
    return AiConfirmation(
      title: 'Book $restaurant at $time?',
      description:
          'Table for ${part.args['party'] ?? 2}. '
          'Free cancellation until 18:00.',
      icon: Icons.restaurant_rounded,
      confirmLabel: 'Book',
      denyLabel: 'Not now',
      status: status,
      onConfirm: wait == null || wait.isCompleted
          ? null
          : () => wait.complete(true),
      onDeny: wait == null || wait.isCompleted
          ? null
          : () => wait.complete(false),
    );
  }

  Widget _message(BuildContext context, AiMessage message) {
    if (message.role == AiRole.user) return AiMessageBubble(message: message);
    if (message.role != AiRole.assistant) return const SizedBox.shrink();

    final calls = message.parts.whereType<ToolCallPart>().toList();
    final sources = message.parts.whereType<SourcePart>().toList();
    final followUps = [
      for (final p in message.parts)
        if (p is DataPart && p.dataType == 'follow_ups')
          for (final item in (p.data['items'] as List? ?? const [])) '$item',
    ];
    final isLatest =
        message.id ==
        _chat.messages.lastWhere((m) => m.role == AiRole.assistant).id;
    final settled = message.status == AiMessageStatus.complete;
    final results = _results;

    final children = <Widget>[
      if (calls.isNotEmpty)
        RunSummary(
          key: ValueKey('run-${message.id}'),
          steps: [
            for (final call in calls)
              runStepFor(
                call,
                results[call.toolCallId],
                running: isLatest && _chat.status.isBusy,
                failed: message.status == AiMessageStatus.error,
              ),
          ],
        ),
      if (_showToolDetails && calls.isNotEmpty)
        AiToolGroup(calls: calls, results: results),
      AiMessageBubble(
        message: message,
        widgetRegistry: _registry,
        partBuilder: _part,
        onPartAction: _onPartAction,
      ),
      if (settled && message.text.isNotEmpty)
        Row(
          children: [
            AiMessageActions(
              message: message,
              onRegenerate: isLatest
                  ? () => unawaited(_chat.regenerate())
                  : null,
            ),
            const Spacer(),
            if (sources.isNotEmpty)
              SourcesButton(
                count: sources.length,
                onTap: () => showSourcesSheet(
                  context,
                  sources,
                  onOpen: (s) => unawaited(
                    launchUrl(s.url, mode: LaunchMode.externalApplication),
                  ),
                ),
              ),
          ],
        ),
      if (isLatest && settled && followUps.isNotEmpty)
        AiSuggestions(
          suggestions: followUps,
          layout: AiSuggestionsLayout.list,
          padding: EdgeInsets.zero,
          onSelected: _chat.status.isBusy ? null : _send,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    // Scrollable so the grid stays reachable with the keyboard open or at
    // large text sizes; pinned to the bottom (near the thumb) otherwise.
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (viewport.maxHeight - 32).clamp(0, double.infinity),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'What can I help with?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Answers show the steps taken and their sources.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color?.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              AiSuggestions(
                suggestions: productionStarters,
                layout: AiSuggestionsLayout.grid,
                padding: EdgeInsets.zero,
                onSelected: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: _chat,
          builder: (context, _) => Column(
            children: [
              ChatHeader(
                title: _title,
                onNewChat: _newChat,
                showToolDetails: _showToolDetails,
                onToggleToolDetails: () =>
                    setState(() => _showToolDetails = !_showToolDetails),
              ),
              Expanded(
                child: Stack(
                  children: [
                    AiChat(
                      controller: _chat,
                      messageBuilder: _message,
                      emptyState: Builder(builder: _emptyState),
                      maxContentWidth: 720,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                    ),
                    // The transcript fades out under the header instead of
                    // meeting a hard edge.
                    PositionedDirectional(
                      top: 0,
                      start: 0,
                      end: 0,
                      height: 20,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                background,
                                background.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_chat.status == ChatStatus.error)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: AiErrorBanner(
                      message: "Couldn't finish: ${_chat.error}",
                      onRetry: () => unawaited(_chat.regenerate()),
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: AiPromptInput(
                    controller: _chat,
                    textController: _draft,
                    focusNode: _composerFocus,
                    hintText: _chat.messages.isEmpty
                        ? 'Ask anything'
                        : 'Ask a follow-up',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

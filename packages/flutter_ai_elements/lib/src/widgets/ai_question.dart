import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ai_elements/src/l10n/ai_localizations.dart';
import 'package:flutter_ai_elements/src/theme/ai_theme_extension.dart';

/// How many suggested answers a question accepts.
enum AiQuestionSelectionMode {
  /// Selecting an option replaces the previous selection.
  single,

  /// Options can be selected and deselected independently.
  multiple,
}

/// A suggested answer with a stable, application-owned value.
@immutable
class AiQuestionOption {
  /// Creates a suggested answer.
  const AiQuestionOption({required this.value, required this.label});

  /// The value returned to the host (unique within a question).
  final String value;

  /// The visible, accessible option label.
  final String label;
}

/// An immutable answer containing selected values and trimmed freeform text.
@immutable
class AiQuestionResponse {
  /// Copies [selectedValues] and trims [text].
  AiQuestionResponse(
      {Iterable<String> selectedValues = const [], String text = ''})
      : selectedValues = List.unmodifiable(selectedValues),
        text = text.trim();

  /// Selected option values, in their display order.
  final List<String> selectedValues;

  /// Additional text, or an empty string.
  final String text;
}

/// An actionable question with choices, freeform text, or both.
///
/// Awaiting [onSubmit] disables the form. Success shows an answered summary;
/// failure keeps the draft and offers retry with a localized error message.
/// This widget never submits a chat message or changes a conversation.
///
/// Use a distinct key for each logical question. Submission guards and drafts
/// live only for this mounted instance. Hosts must persist accepted [answer]s
/// and guard in-flight requests (using [enabled]) across lazy-list eviction,
/// remounts and process restarts. The host/backend owns action idempotency.
class AiQuestion extends StatefulWidget {
  /// Creates a question. Enable [allowFreeform] for a text-only question.
  const AiQuestion({
    super.key,
    required this.prompt,
    this.description,
    this.options = const [],
    this.selectionMode = AiQuestionSelectionMode.single,
    this.allowFreeform = false,
    this.onSubmit,
    this.answer,
    this.enabled = true,
    this.submitLabel,
    this.inputLabel,
    this.errorMessage,
  }) : assert(options.length > 0 || allowFreeform);

  /// The question displayed above the form.
  final String prompt;

  /// Optional supporting explanation.
  final String? description;

  /// Suggested answers, with unique values. Treat this list as immutable.
  final List<AiQuestionOption> options;

  /// Whether to accept one suggested answer or several.
  final AiQuestionSelectionMode selectionMode;

  /// Whether to show a multiline freeform field.
  final bool allowFreeform;

  /// Called once per submission attempt; null makes the form inert.
  /// Throw to retain the draft and show [errorMessage] (or its localized default).
  final FutureOr<void> Function(AiQuestionResponse response)? onSubmit;

  /// A host-owned accepted answer, restored after remounts or persistence.
  /// While non-null the form is replaced by an inert summary.
  final AiQuestionResponse? answer;

  /// Whether editing/submitting is allowed, e.g. false while the host is busy.
  final bool enabled;

  /// Submit label; defaults to the localized "Answer".
  final String? submitLabel;

  /// Freeform field label; defaults to the localized "Your answer".
  final String? inputLabel;

  /// Safe user-facing failure message. Exceptions are not displayed verbatim.
  final String? errorMessage;

  @override
  State<AiQuestion> createState() => _AiQuestionState();
}

class _AiQuestionState extends State<AiQuestion> {
  final TextEditingController _text = TextEditingController();
  final Set<String> _selected = {};
  bool _pending = false;
  bool _failed = false;
  AiQuestionResponse? _accepted;

  AiQuestionResponse? get _answer => widget.answer ?? _accepted;
  bool get _enabled =>
      widget.enabled && widget.onSubmit != null && !_pending && _answer == null;
  bool get _hasResponse =>
      _selected.isNotEmpty ||
      (widget.allowFreeform && _text.text.trim().isNotEmpty);

  @override
  void didUpdateWidget(AiQuestion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selected.retainAll(widget.options.map((option) => option.value));
    if (widget.selectionMode == AiQuestionSelectionMode.single &&
        _selected.length > 1) {
      final first =
          widget.options.firstWhere((o) => _selected.contains(o.value));
      _selected
        ..clear()
        ..add(first.value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_enabled || !_hasResponse) return;
    final response = AiQuestionResponse(
      selectedValues: widget.options
          .where((option) => _selected.contains(option.value))
          .map((option) => option.value),
      text: widget.allowFreeform ? _text.text : '',
    );
    setState(() {
      _pending = true;
      _failed = false;
    });
    try {
      await widget.onSubmit!(response);
      if (mounted) setState(() => _accepted = response);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
        widget.options.map((o) => o.value).toSet().length ==
            widget.options.length,
        'Question option values must be unique.');
    final theme = AiThemeExtension.of(context);
    final strings = AiLocalizations.of(context);
    final answer = _answer;
    final multiple = widget.selectionMode == AiQuestionSelectionMode.multiple;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.prompt,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (widget.description != null) ...[
            const SizedBox(height: 4),
            Text(widget.description!),
          ],
          const SizedBox(height: 12),
          if (answer != null)
            Semantics(
              liveRegion: true,
              child: Text('${strings.questionAnswered}: ${_summary(answer)}'),
            )
          else ...[
            for (final option in widget.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  checked: _selected.contains(option.value),
                  inMutuallyExclusiveGroup: !multiple,
                  enabled: _enabled,
                  child: Material(
                    color: _selected.contains(option.value)
                        ? theme.effectiveChipColor
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: _selected.contains(option.value)
                            ? theme.accentColor
                            : theme.borderColor,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: !_enabled
                          ? null
                          : () => setState(() {
                                if (!multiple) {
                                  _selected
                                    ..clear()
                                    ..add(option.value);
                                } else if (!_selected.remove(option.value)) {
                                  _selected.add(option.value);
                                }
                              }),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Icon(
                              multiple
                                  ? (_selected.contains(option.value)
                                      ? Icons.check_box_outlined
                                      : Icons.check_box_outline_blank)
                                  : (_selected.contains(option.value)
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked),
                              size: 20,
                              color: theme.accentColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(option.label)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.allowFreeform)
              TextField(
                controller: _text,
                enabled: _enabled,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: widget.inputLabel ?? strings.questionInputLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            if (_failed) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(widget.errorMessage ?? strings.questionError,
                    style: TextStyle(color: theme.errorColor)),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.onAccentColor,
                minimumSize: const Size(48, 48),
              ),
              onPressed: _enabled && _hasResponse ? _submit : null,
              child: Text(_pending
                  ? strings.questionSubmitting
                  : _failed
                      ? strings.retry
                      : widget.submitLabel ?? strings.questionAnswer),
            ),
          ],
        ],
      ),
    );
  }

  String _summary(AiQuestionResponse response) {
    final labels = {
      for (final option in widget.options) option.value: option.label
    };
    return [
      for (final value in response.selectedValues) labels[value] ?? value,
      if (response.text.isNotEmpty) response.text,
    ].join(' · ');
  }
}

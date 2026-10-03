# groundwork — #155 production mobile agent recipe

Tree: 0fef4306bd5f8e10d7a3f69d1feab95ad014f704

## Task

flutter_ai_elements gains opt-in mobile presentation hooks (suggestion list/grid layouts, confirmation status, composer focus node, transcript keyboard dismissal) and the demo gains a production conversation recipe that shows ask → progress → answer/sources → follow-up, plus loading, empty, failed/retry, approval and settled states.

## Facts

- F1 — `AiSuggestions.onSelected` is still a required named parameter, now nullable, so existing callers compile unchanged — `rg -n onSelected packages/flutter_ai_elements/lib/src/widgets/ai_suggestions.dart` → `28:    required this.onSelected,` and `38:  final ValueChanged<String>? onSelected;`
- F2 — every new widget parameter has a default that keeps the old behavior (`layout` row, `status` awaiting, `keyboardDismissBehavior` manual) — `rg -n "this.layout = |this.status = |this.keyboardDismissBehavior = " packages/flutter_ai_elements/lib` → `ai_suggestions.dart:30 this.layout = AiSuggestionsLayout.row`, `ai_confirmation.dart:55 this.status = AiConfirmationStatus.awaiting`, `ai_chat.dart:41` and `ai_conversation_view.dart:34 ScrollViewKeyboardDismissBehavior.manual`
- F3 — `PartReceived` only appends a part; a streamed DataPart cannot be updated in place, so live progress must come from tool-call state, not a re-sent task DataPart — `rg -n "case PartReceived" -A3 packages/flutter_ai_core/lib/src/streaming/message_processor.dart` → `188: case PartReceived(...)` followed by `parts: [...m.parts, part]` (line 192, seen in the same read)
- F4 — the controller settles unanswered tool calls with an error result whose text starts with "Cancelled: the turn was interrupted" before submit/regenerate/edit — `rg -n "Cancelled: the turn was interrupted" packages/flutter_ai_client/lib/src/use_chat_controller.dart` → `700: result: 'Cancelled: the turn was interrupted before this tool '`
- F5 — a `messageBuilder` output is never memoized by `AiConversationView`, so host state captured in it refreshes on each parent rebuild — `rg -n "if \(widget.messageBuilder != null\)" packages/flutter_ai_elements/lib/src/widgets/ai_conversation_view.dart` → `127:    if (widget.messageBuilder != null) {`
- F6 — demo golden output is git-ignored and CI only tests `packages/*` — `rg -n demo/test/shots .gitignore` → `17:demo/test/shots/`; `rg -n "flutter test|dart test" .github/workflows/ci.yml` → `63: (cd "$pkg" && flutter test)`
- F7 — the elements package is at 0.4.0 before this change (user approved a 0.5.0 bump) — `rg -n "^version" packages/flutter_ai_elements/pubspec.yaml` → `3:version: 0.4.0`
- F8 — the confirmation progress indicator respects reduced motion — `rg -n maybeDisableAnimationsOf packages/flutter_ai_elements/lib/src/widgets/ai_confirmation.dart` → `202:    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;`
- F9 — tool calls that already have a ToolResultPart are not handed to `onToolCalls`, so server-run research steps with inline results will not re-execute locally — `rg -n "_pendingToolCalls\(\)" -A12 packages/flutter_ai_client/lib/src/use_chat_controller.dart | rg -n "ToolResultPart"` → `727-          if (p is ToolResultPart) p.toolCallId,`

## Blast radius

Enumerated by: `rg -n "AiSuggestions\(|AiSuggestionsLayout" --glob '!demo/lib/production/**'` → 4 non-test sites; `rg -n "AiConfirmation\(|AiConfirmationStatus" --glob '!demo/lib/production/**'` → 5 non-test sites; `rg -n "AiComposer\(|AiPromptInput\("` → 9 code sites + docs; `rg -n "AiChat\(|AiConversationView\(" --glob '*.dart'` → 6 non-test sites; `rg -n "AiLocalizations\(" --glob '*.dart'` → constructors only

- B1 — packages/flutter_ai_client/lib/src/follow_ups.dart:13 — doc comment shows `AiSuggestions(suggestions:, onSelected:)` — SAFE — the snippet stays valid (F1)
- B2 — demo/lib/demo_data.dart:302 — gallery `AiSuggestions` row — SAFE — default `layout` is row (F2)
- B3 — packages/flutter_ai_elements/lib/src/widgets/ai_suggestions.dart:25 — the widget itself; row chips now wrapped in `Semantics(button)` — UPDATE — done; covered by mobile_presentation_test.dart
- B4 — demo/lib/main.dart:559, demo/lib/main.dart:660, demo/lib/feature_sections.dart:281, demo/lib/demo_data.dart:271 — existing `AiConfirmation` callers with no status — SAFE — default awaiting renders the same buttons (F2)
- B5 — packages/flutter_ai_elements/test/a11y_i18n_test.dart:198 and test/widgets_test.dart:89 — assert Allow/Deny text, contrast and text-scale growth — SAFE — awaiting path keeps the same `_Button` widgets; full package suite passed after the edit
- B6 — packages/flutter_ai_elements/lib/src/widgets/ai_chat_view.dart:84,95 — builds `AiChat` and `AiPromptInput` without the new params — SAFE — defaults keep manual dismissal and an internal focus
- B7 — packages/flutter_ai_elements/lib/src/widgets/ai_prompt_input.dart:78 — forwards new `focusNode` to `AiComposer` — UPDATE — done
- B8 — demo/lib/live_demo.dart:212 and demo/test/capture_test.dart:180,209 — `AiConversationView`/`AiComposer` uses — SAFE — no new required params
- B9 — packages/flutter_ai_elements/lib/src/widgets/ai_composer.dart:199 — `textCapitalization: sentences` on the shared composer field — UPDATE — behavior change for every composer on soft keyboards; record in CHANGELOG
- B10 — packages/flutter_ai_elements/lib/src/l10n/ai_localizations.dart:22 — four new optional strings with English defaults — SAFE — const constructor keeps every call site valid; delegate/scope unchanged
- B11 — packages/flutter_ai_elements/CHANGELOG.md and pubspec.yaml — release notes and version — UPDATE — add 0.5.0 entry (F7)
- B12 — demo/lib/main.dart hero header — entry point to the new recipe screen — UPDATE — add a link without changing the gallery
- B13 — demo/test/capture_test.dart and demo/integration_test/screenshots_test.dart — screenshot generators — UPDATE — add production-recipe frames; goldens stay local (F6)

## Invariants

- I1 — every existing call site of `AiSuggestions`, `AiConfirmation`, `AiComposer`, `AiPromptInput`, `AiChat`, `AiConversationView` and `AiLocalizations` compiles and renders the same widgets without edits — breaks if: `dart analyze` reports an error in demo/ or packages/ after the change, or an existing test asserting Allow/Deny or chip text fails
- I2 — an `AiConfirmation` with status other than awaiting exposes no tappable Allow or Deny control — breaks if: a widget test finds the text "Allow" or "Deny" for status submitting, approved, denied or expired
- I3 — the recipe never runs `book_table` without an explicit Allow tap — breaks if: the scripted `book_table` call gets a non-error ToolResultPart in a test where the user tapped Deny, stopped, or sent a new message instead
- I4 — the run summary is built only from ToolCallPart/ToolResultPart state, never from ReasoningPart text — breaks if: the recipe source references `ReasoningPart` or `reasoning` in the summary builder
- I5 — follow-up suggestions are disabled while the controller is busy — breaks if: tapping a follow-up during streaming calls `sendText`
- I6 — the starter grid falls back to one column when width / textScale is under 300 logical pixels — breaks if: at width 320 and text scale 2 the second card sits to the right of the first

- I7 — after Stop or a new message during an approval wait, no `AiConfirmation` for that call is awaiting — breaks if: a test taps Stop while `book_table` waits and then finds "Allow"
- I8 — an answered question stays answered after its row is evicted and rebuilt — breaks if: a test answers, scrolls the question out of the lazy list, scrolls back, and finds the "Answer" button
- I9 — the failed flight run and a stopped run show no in-progress step — breaks if: a test finds an active task item (or "Working") after the flight error or after Stop

## Plan

- P1 — library: suggestion layouts, confirmation status + strings, question answered check, composer capitalization + focus node, transcript keyboard dismissal, with tests — rests on F1, F2, F8, B3, B7, B9, B10, I1, I2, I6
- P2 — demo: scripted ProductionAgentProvider (research, failing-then-retry flight, question → result card, approval-gated booking) — rests on F3, F9
- P3 — demo: ProductionChatScreen using AiChat + messageBuilder (run summary from tool state, AiMessageBubble with registry/partBuilder/onPartAction, sources sheet, list follow-ups, approval gate via `onToolCalls`, inline error with retry) — rests on F4, F5, I3, I4, I5, I7, I8, I9
  - A1: approval status = host gate state while the executor waits; `expired` once `signal.whenCancelled` fires (Stop/dispose) or the call has an isError result starting "Cancelled"; `approved`/`denied` from the ToolResultPart.
  - A2: question answers live in a host map keyed by AiPartRef and are passed as `answer:`; the submit guard rejects a second answer for the same ref.
  - A3: a step with no result is `active` only while its message is the last assistant message and the controller is busy; otherwise `error` (message error, Stop) — never derived from reasoning.
- P4 — demo: link from the hero header; production entry point — rests on B12
- P5 — demo tests: interaction flow tests and local goldens (light, dark, RTL, large text, narrow) — rests on F6, B13, I3, I5
- P6 — docs, CHANGELOG 0.5.0, Mobbin attribution; real device screenshots — rests on F7, B11

## Unknowns

- U1 — whether Android and iOS keyboards keep the transcript stable when the composer gains focus mid-stream — resolved by: running the recipe on the leased Android emulator and iOS simulator and capturing screenshots
- U2 — whether the Mobbin screens beyond the one re-fetched (Perplexity fe1aa2bb) still show what the review recorded — resolved by: the October 3 review document's recorded observations; cite them as such

## Hunts

- H1 — hunt — complete — 3

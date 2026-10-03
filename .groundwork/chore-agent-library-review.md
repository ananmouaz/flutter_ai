# Interactive transcript foundation
Tree: 42443c7677c972a8d32cc919619e00723ce9f7b5

## Task
Standard transcripts render registered/custom parts, report addressed actions, and display accessible questions with asynchronous submission.

## Facts
- F1 — Data parts fall back to chips in default bubbles — `sed -n '95,160p' packages/flutter_ai_elements/lib/src/widgets/ai_message_bubble.dart` → `children.add(_DataChip(label: dataType));`
- F2 — Registry builders accept context and data only — `cat packages/flutter_ai_elements/lib/src/generative_ui/ai_widget_registry.dart` → `Widget Function(BuildContext context, Map<String, Object?> data)`
- F3 — Transcript caches bubbles by message identity — `cat packages/flutter_ai_elements/lib/src/widgets/ai_conversation_view.dart` → `identical(_cachedMessage[message.id], message)`
- F4 — Arbitrary received parts append to the message — `rg -n 'PartReceived|parts: \[' packages/flutter_ai_core/lib/src/streaming/message_processor.dart` → `parts: [...m.parts, part]`
- F5 — Demo replaces the parts loop and resolves results across messages — `sed -n '490,690p' demo/lib/main.dart` → `_buildMessage`, `for (final m in controller.messages)`, `switch (part)`
- F6 — Question defaults can extend existing additive localization — `head -150 packages/flutter_ai_elements/lib/src/l10n/ai_localizations.dart` → English constructor defaults and final string fields

## Blast radius
Enumerated by: `rg -n 'AiChat\(|AiChatView\(|AiConversationView\(|AiMessageBubble\(|AiDataView\(|AiWidgetRegistry|switch \(part\)' packages demo`
- B1 — elements ai_message_bubble.dart — renders parts — UPDATE — builder precedence, scoped context, registry fallback
- B2 — elements ai_conversation_view.dart, ai_chat.dart, ai_chat_view.dart — forwards options and caches — UPDATE — forward registry/builder/action; bypass memoization for custom content that can capture mutable state
- B3 — elements ai_widget_registry.dart — public builder contract — SAFE — keep existing two-argument builder signature; context gains an inherited action scope in a transcript
- B4 — core model and processor — serialization/replay — SAFE — elements-only positional identity; no core edits
- B5 — demo/lib/main.dart — customized transcript — UPDATE — replace switch with default bubble plus per-part overrides; preserve cross-message tool results, confirmation, sources and action footer
- B6 — elements exports, l10n, tests, README, CHANGELOG and demo gallery — public API and examples — UPDATE — export/add/document question and interactions with focused tests
- B7 — existing direct bubble/view tests, demo captures, live demo and package example — callers using defaults — SAFE — nullable additions preserve constructor compatibility; run suites to verify

## Invariants
- I1 — No optional hook means the existing part widgets and message styling remain — breaks if: an unknown DataPart disappears instead of rendering its chip
- I2 — Actions report message ID, original part index and value without mutating history — breaks if: tapping a control appends a user message before the host handles it
- I3 — Core JSON and event replay remain identical — breaks if: new positional identity is persisted into AiPart JSON
- I4 — A part builder returning null falls through to registry then default rendering — breaks if: null hides a text part
- I5 — Custom builders observe the bubble's DefaultTextStyle and inherited theme — breaks if: builders execute above the styling wrapper
- I6 — Custom content updates on parent rebuild despite unchanged message identity — breaks if: registry registration or captured approval state changes but the cached bubble remains
- I7 — Within one mounted question, submission occurs at most once while pending and once after success — breaks if: double taps invoke two asynchronous callbacks
- I8 — Failed question submission preserves input and permits retry; disposal cannot set state — breaks if: a failed Future clears the draft or a late completion updates an unmounted state
- I9 — Positional references refer only to the displayed message snapshot — breaks if: callers reuse indices after replacing or reordering message parts
  - Document this restriction and expose no automatic controller routing. User selected positional identity via ask_human.
- I10 — Null action handlers produce an inert supplied action callback; streaming bubbles offer no scoped action — breaks if: a scope submits while the message is hidden from semantics during streaming

- I11 — Restored answers render inert after lazy-list eviction/remount — breaks if: a host supplies an answer but the remounted form accepts submission
  - Host owns durable answer and pending state across unmounts; widget-instance guards alone do not guarantee this. Demo keeps answers and tests cover remount.

## Plan
- P1 — Add immutable AiPartRef and inherited AiPartScope with nullable asynchronous action callback; retain existing registry builder signature — rests on F2, F4, I2, I3, I9
- P2 — Add registry/builder/action fields across all four wrappers; invoke each part builder below scope and style; preserve fallback ordering and keys — rests on B1, B2, I1, I4, I5, I10
- P3 — Bypass bubble memoization for custom part builders, registries or action handlers — rests on F3, I6
- P4 — Add AiQuestion with single/multiple selection, optional freeform, immutable submitted response, pending/error/answered states and optional restored answer; native focus/semantics and localized labels — rests on F6, B6, I7, I8
- P5 — Replace demo manual part switch with default bubble plus per-part overrides; add question gallery example through standard transcript — rests on F5, B5, B6
- P6 — Test wrapper forwarding, fallback, scope styling, cache refresh, unchanged JSON/replay, null/streaming actions, question async races, accessibility and narrow/RTL/large text; run workspace gates — rests on B7, I1, I2, I3, I4, I5, I6, I7, I8, I10

## Unknowns
none

## Hunts
- H1 — hunt — complete — 1

# groundwork — AiQuestion submit label unreadable while enabling

Tree: 2064ece3d1374d922effcd82a9b9cc33cabbfc3b

## Task

When a user picks an option in `AiQuestion`, the submit button turns the
accent color at once but its label fades from the disabled color over 200 ms,
so it reads as a black button with no text. Make the label change with the
background, and ship it as flutter_ai_elements 0.5.1.

## Facts

- F1 — the background switches in the same frame and the label lerps over ~200 ms — temporary widget test in demo/ printing `Material.color` and the label `RenderParagraph` color every 50 ms → `0: bg=0x0D0D0D text=alpha 0.38` … `200: text=white`
- F2 — `ButtonStyle.animationDuration` drives the button's `Material` animation, which animates the label's text style — `rg -n animationDuration flutter/lib/src/material/button_style_button.dart` → `449: (ButtonStyle? style) => style?.animationDuration,` and `607: animationDuration: resolvedAnimationDuration,`
- F3 — the button style lives in one place — `rg -n "styleFrom" packages/flutter_ai_elements/lib` → only `ai_question.dart:296`
- F4 — the package is at 0.5.0 — `rg -n "^version" packages/flutter_ai_elements/pubspec.yaml` → `3:version: 0.5.0`

## Blast radius

Enumerated by: `rg -n "AiQuestion\(" packages demo --glob '*.dart' --glob '!**/test/**'` → 3 call sites

- B1 — demo/lib/main.dart:563 — showcase question — SAFE — no style param exposed; only the transition changes
- B2 — demo/lib/demo_data.dart:87 — gallery question — SAFE — same
- B3 — demo/lib/production/production_chat.dart:214 — recipe question — SAFE — same; result_card golden taps Answer after settling
- B4 — packages/flutter_ai_elements/CHANGELOG.md, pubspec.yaml — release notes and version — UPDATE — 0.5.1 (F4)

## Invariants

- I1 — in the frame the button becomes enabled, its label color equals `onAccentColor` — breaks if: the new test in ai_question_test.dart reads any other color after one pump
- I2 — the disabled button still uses the framework disabled colors — breaks if: the existing test asserting `onPressed` is null sees a different visual state (covered by the full package suite)

## Plan

- P1 — set `animationDuration: Duration.zero` on the submit button — rests on F1, F2, F3, I1
- P2 — regression test, CHANGELOG 0.5.1, version bump — rests on F4, B4

## Hunt

- H1 — Could `Duration.zero` remove a visible elevation animation? FilledButton has elevation 0 in every state for M3, so there is nothing to animate — checked by the full package suite and the result_card shot.

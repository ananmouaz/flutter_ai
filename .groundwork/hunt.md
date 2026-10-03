# Groundwork hunt

Record: `.groundwork/chore-agent-library-review.md`
Verdict: complete
Tree digest: 317957168d2c76ee79a1fdec2f1e82e14fa765d2
Record hash (SHA-1): 15a6b5b86d84168dcb6a515b03bb45f97a86afef
Accepted count: 1

## Accepted findings

[A1] Invariant nothing enforces — question submission state must survive transcript eviction through host-owned restoration, or the at-most-once promise must explicitly be instance-local.
Found by: `cat packages/flutter_ai_elements/lib/src/widgets/ai_conversation_view.dart` and `rg -n 'keepAlive|AutomaticKeepAlive|findChildIndexCallback|itemBuilder' packages/flutter_ai_elements/lib/src/widgets/ai_conversation_view.dart` show a lazy `ListView.builder` at line 132 with no durable form-state owner. I7 currently promises a single successful submission, while P4 only says an optional restored answer exists. A question disposed after scrolling away can return as a fresh unanswered widget; disposal during a pending submission similarly loses the UI guard.
Why material: asynchronous race tests currently cover disposal but do not cover disposal/remount followed by resubmission. A local boolean cannot promise transcript-wide at-most-once behavior.
Add to the record: specify I7 as widget-instance submission suppression; document that hosts own durable answers and any pending/idempotency guard across remounts, keyed by the snapshot-compatible reference. Demonstrate storing successful answers in the gallery and restoring them on remount, and add a transcript eviction/remount test. If transcript-wide at-most-once is intended, explicitly plan the durable owner instead.

## Rejected candidates

- Cache freshness and builder styling context: I5/I6 and P2/P3 already cover both concrete problems.
- Cross-message tool results and grouped demo tools: F5/B5/P5 explicitly preserve these customization paths.
- Positional identity after replacement/reordering: I9 records the chosen restriction; persistent part identity is explicitly outside this approved design.
- Existing AiMessage parts list is not defensively copied: this task adds no mutation or persistence route; no core change is necessary.
- Existing registry callers without an action scope: B3 keeps the two-argument signature; optional scope preserves standalone usage.
- Additional external consumers: additive constructors and unchanged core serialization provide no evidence of a required external migration.

## Coverage

All six lenses applied once:

1. Unverified claims: reran exact F1–F6 commands; all establish their recorded claims. Pre-hunt validator passed (29 rows).
2. Second paths: reran the recorded enumeration; widened to imports/re-exports and AiDataWidgetBuilder/AiConversation spellings across Dart and to symbol spellings in non-Dart, non-Markdown files. Inspected core model serialization and processor append behavior, elements exports/callers, live demo, capture tests and standalone package example. No omitted reached production path found.
3. SAFE evidence: opened B3 registry builder/build/AiDataView; B4 AiMessage/AiPart serialization and processor append; B7 existing registry/bubble tests, live demo transcript, captures and package example. These support additive compatibility.
4. Invariant falsification: I1 checked existing switch fallback; I2/I3 checked elements-only design versus model serialization; I4 checked registry nullable fallback; I5 checked DefaultTextStyle boundary; I6 checked message-identity cache; I7/I8 checked lazy widget lifetime (A1); I9 checked message copy/replacement semantics; I10 checked ExcludeSemantics during streaming.
5. Enforcement: I1/I4/P2 use ordered fallback; I2/P1 scoped callback without controller; I3 unchanged core types; I5/P2 descendant Builder; I6/P3 cache bypass; I7/I8/P4 pending/answered guard plus mounted checks (A1 adds lifetime limit); I9 API documentation; I10 nullable streaming callback. New mechanisms are planned, not yet implemented, so no implementation test pass is claimed.
6. Unnamed unknowns: lifecycle ownership gap accepted as A1. No network/provider behavior is changed; no external guarantee is needed for the proposed host-owned restoration contract.

Not checked: implementation correctness and new widget behavior, because implementation has not begun. Existing baseline suite result belongs to the parent, not this hunt.

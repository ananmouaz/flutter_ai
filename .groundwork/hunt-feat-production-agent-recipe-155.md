# Groundwork hunt

Record: `.groundwork/feat-production-agent-recipe-155.md`
Verdict: complete
Accepted count: 3

## Accepted findings

- [A1] Second path — `UseChatController.stop()` cancels the approval executor without settling `book_table`; a transcript-derived card would stay `awaiting`. Fold: status becomes `expired` on `signal.whenCancelled` or a "Cancelled" error result; invariant I7 and a Stop test.
- [A2] Second path — lazy transcript eviction remounts the passport `AiQuestion` unanswered. Fold: host-owned answers passed as `answer:`; invariant I8 and a scroll-away test.
- [A3] Second path — tool parts alone cannot tell running, awaiting, stopped and failed apart. Fold: combine message status and controller status for the last assistant message; invariant I9 and tests.

## Rejected candidates

- Demo tests not in CI — already recorded by F6.
- Capitalisation on the AiQuestion field — same change class as B9.
- AiQuestion answered icon without a B row — covered by P1 and passing tests.
- Nullable `onSelected` breaking external readers — no reader exists; speculative.
- 0.5.0 bump breaking dependents — all dependents use path dependencies.
- I6 one column on 320 pt phones at scale 1 — consistent with I6.
- AiChatView not forwarding new params — B6 covers it.
- Busy controller during approval — consistent with I5; submit settles the call (F4).
- Follow-up text hitting the trains script — demo content detail.

## Coverage

All six lenses applied once: facts F1–F9 re-run; enumeration widened; SAFE rows B1, B2, B4, B5, B6, B8, B10 opened; I1–I6 falsification attempted; enforcement identified; U1, U2 judged reasonable.

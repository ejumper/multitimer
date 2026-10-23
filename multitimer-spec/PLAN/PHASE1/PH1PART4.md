# PH1PART4 — Timer Engine Semantics

Part of [Phase 1](./OVERVIEW.md). [CONVENTIONS.md](./CONVENTIONS.md) binds this task.

**This is the hardest recon part.** Behavioral clarity beats mechanical completeness:
the deliverable describes *what the app does*, with mechanism only where discoverable.
"Couldn't determine" is an acceptable, expected outcome for sub-questions — put it in
GAPS rather than guessing.

## 1.0 Objective

Document the timer engine as a behavioral spec: timer types, the state machine of a
timer's lifecycle, timer-to-timer linking/sequential behavior, and what happens when
timers hit zero.

## 2.0 Prerequisites (STOP if unmet)

- `FINDINGS/data-model.md` (entity/enum names are your engine vocabulary),
  `WORK/MAP.md` "Where to look → engine".

## 3.0 Procedure

1. **Vocabulary first:** from data-model enums + `res/values/strings.xml`, list the
   timer types the app actually has (e.g. countdown / count-up / stopwatch / pomodoro
   / interval…) with their user-facing names from REFERENCE.
2. **State machine:** for a single timer, determine states and legal transitions:
   - States (idle / running / paused / finished / others found in code)
   - Events: user actions (start, pause, resume, reset, edit-while-running?) and
     system events (app backgrounded, timer hits zero)
   - Transition effects, incl. edge cases: pause during last second, edit duration
     mid-run, delete a running timer, two timers with same end time
   - `rg` starting points: `CountDownTimer|elapsedRealtime|isRunning|onFinish`
3. **Zero-crossing behavior** per timer type: what fires (Part 5 covers *how* it's
   delivered), auto-restart?, continue as count-up?, requires-acknowledgement?, and
   how "completed" is recorded in history.
4. **Linking / sequencing** — the feature this whole project is about:
   - `rg`: `chain|sequence|link|next|activat` within APP code + REFERENCE help docs
     for the official description of the feature
   - Document: how a link is defined (data model), start semantics (A ends → B starts:
     delay? conditions?), pause propagation, cycles (A→B→A allowed?), limits, and
     interaction with manual starts.
5. **Boards & concurrency:** rules for multiple running timers on one board, board
     switching while running **(PRO)** where applicable.

## 4.0 Deliverables

`FINDINGS/engine.md` per CONVENTIONS format:
- `## 1.0 Timer types`
- `## 2.0 Single-timer state machine` (a states/transitions table)
- `## 3.0 Zero-crossing behavior`
- `## 4.0 Linking & sequencing` ← the centerpiece; be exhaustive here
- `## 5.0 Boards & concurrency`
- `## GAPS` / `## CONFIDENCE`

## 5.0 Self-Verification Checklist

- [ ] Every transition row cites source (code file+lines or REFERENCE doc)
- [ ] Linking section answers: definition, start semantics, delay, pause, cycles, limits
- [ ] Edge cases addressed or explicitly gapped (not silently skipped)
- [ ] Cross-checked feature descriptions against at least 2 REFERENCE docs

## 6.0 Escalation guidance

If obfuscated call chains become unnavigable (Part 2 rated heavy and it shows): do NOT
brute-force trace. Reconstruct behavior from (a) data model, (b) strings/log messages,
(c) help docs, mark confidence Low, list the untraceable mechanisms in GAPS, and
consider a BLOCKERS.md entry recommending a narrower follow-up task instead.

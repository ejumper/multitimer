# Planner v2 — Build Plan Overview

> **What this is:** the execution plan for v2 of **Planner** — the "wide but shallow" batch that turns the v1 timer into a day planner. Versions are *batches*, not marketing: when v2 is done the user drives it daily for a month or two and v3 is defined from what's actually missing.
> **Decisions of record:** `new-app/v2/v2-outline.md` (brain dump) **refined and superseded where they conflict by the 2026-11-07 design discussion** (this plan encodes its outcome). `new-app/FINAL-APP-OUTLINE.md` (the North Star) remains the long-term vision; **v2-outline.md overrides it on conflicts**. Parked ideas: `new-app/v3/v3-ideas.md`. v1's plan/conventions: `new-app/v1/PLAN/`.

## v2 in one sentence

Same app, new identity: intervals gain **completion state**, **optional duration**, and **trigger time** (dated walls) — and the dial is replaced by an **editor-style list view** where checking items *is* the interaction; timers become a unified plan type (**Library**, which absorbs tasks and templates as folders), and the **calendar** gives each day a plan (lazy-forked from the library) with **New Events** quick capture.

## The converged model (the spec in brief)

1. **The interval has four core properties** (North Star §1): completion (completed/not) · duration (has/none = **Open**) · finish method (auto-finish/manual) · trigger (order/**date**). Named shapes: **Timed** = order+duration, **Dated** = date-triggered, **Open** = order + no duration + manual (task-like). *Auto-finish requires a duration.* Dated intervals live in **walls**.
2. **Completion is orthogonal to execution.** Marks live on the plan item; terminal states (`done`/`cut`/`skipped`/`moved`) record execution, marks record the work. Check the *current* item → it finishes it + marks completed (advance); check a *future* item → marks completed and the run **flies past** it when reached; check any past item anytime. Enter = completed at holds; one **"not completed"** button resolves a hold otherwise. Auto-finish intervals auto-complete; `cut`/`skipped` default to not-completed. **Reset rewinds the run AND clears all completion marks.**
3. **Walls fire as interrupt & resume** (top-insertion makes the North Star's jump-&-skip wording unusable): at its trigger time a dated interval interrupts whatever runs — the interrupted item is **suspended** (not cut, not logged) — the wall runs (no duration → alarm + hold at its time), and on completion the suspended item **resumes with its remaining time in the state it was in**. A held item auto-resolves (completed) when a wall takes over. A wall firing while *another wall* runs cuts it (`cut`, later-cuts-earlier). Past-due walls fire at the run's start, flagged late. A run that ends with a wall pending shows a paused countdown to it. Overlaps are **blocked at capture** in v2 (editing may still create them → later cuts earlier).
4. **The list view replaces the dial** (v3's list-view spec, physics deferred): editor-style rows with the circular slot becoming the **completion checkbox**, per-row fill, `<left>/<total>` countdown, group repeat countdowns, completed rows semi-transparent, "wait" + pulsing border at holds, current row closest-to-center with autoscroll. Right-click a row = jump (the choose modal dies).
5. **Plans are one kind of thing.** A **folder**-organized **Library** holds routines, task lists, projects; templates are just folders ("save to folder"). A timer whose intervals are all Open behaves as a **checklist** by default (checked items sink below a completed section after 3s, show/hide toggle) — overridable; run controls stay on every timer. Default rules live on library plans: global default / day-of-week / day-of-month / specific date (monthday overrides weekday; a specific date overrides both).
6. **Days lazy-fork their plan.** `date → plan reference` is a **placeholder** (reads — board render, calendar counts — never materialize); the **first write** (plan edit, checkmark, adjustment, or run start) materializes a private copy of the plan *as it stands at that moment*, with completion marks cleared. Library edits reach future days by arrival; lived days stay frozen; "save to folder" is the explicit write-back. Task lists are library plans used in place (marks persist).
7. **New Events** = quick capture of a dated interval: date boxes + time + "Overwrite Default Timer" toggle, **Save** (insert as the *first* interval of the target day's plan) or **Save & edit timer** (insert + open that day's editor on it). Projection-aware insertion is explicitly v3.

## Structure

Phases → numbered chunks. One chunk = one implementation session (orchestrator, optionally delegating mechanical work to the execute sub-agent), one squash-quality commit + changelog entry per chunk, pinned tests per behavior, suite green at all times. **User verification checkpoint at the end of every phase** (fresh bundle via `scripts/build.sh`; `scripts/install.sh` only at the very end).

| Phase | Title | Chunks | Verifies via |
| --- | --- | --- | --- |
| P1 | The 4-property engine + editor | model/schema · Open semantics · completion semantics · walls · editor toggles | engine matrices + editor eyeball + dated firing on the (still present) dial |
| P2 | The list view (the dial dies) | list core · completion interaction · jump & scroll · board polish | **user checkpoint**: daily-driving one timer |
| P3 | The Library | nav shell + bar · library page · checklist mode · rules + save-to-folder | **user checkpoint**: task lists, folders, "Gym is Mondays" |
| P4 | Calendar & days | day model + lazy fork · calendar page · day boards | **user checkpoint**: browse / plan tomorrow / run today |
| P5 | New Events, settings & shell | capture flow · settings · bar + chevrons polish · close-out | **user acceptance walkthrough** (v2/ACCEPTANCE.md) |

## Risk register (each has a designed mitigation)

1. **Wall semantics are the riskiest engine work** (suspend slot, takeover cases, past-due). Mitigation: P1.4 is a named-test matrix written before the code, and it gets its eyeball verification on the dial *before* the P2 display swap lands on top of it.
2. **The list view is the biggest visible change.** Mitigation: P2 renders the exact row vocabulary you already trust from the timer editor (extracted, not re-invented), and the interaction rules are the already-agreed sentences (current → finish+complete; future → fly past).
3. **Lazy fork correctness** (placeholder reads staying read-only, first-write materialization, marks clearing). Mitigation: P4.1 pins each rule as a storage test before any calendar UI exists.
4. **Headless visual verification is unavailable** (Plasma portal — v1 lesson): every phase's look is user-eyeballed on the built bundle. Structure/text widget tests only; no goldens.
5. **Scope creep from the outline's "open to ideas" spots** (date-setter look, New Event quick action). Mitigation: boring defaults are chosen in-plan (month-grid picker; no quick action), flagged for the phase review, refined only if they hurt in daily use.

## Explicitly OUT of v2 (agreed)

Interval descriptions · moving work between days (the `moved` terminal is pre-paid only) · the remainder-actions menu (superseded by suspend & resume) · pre-wall warnings / rebalance-to-fit · recurring dated events · notification action buttons (still parked) · the v3 list-view scroll physics (deadzone/slowdown) · markdown storage / .cal compatibility · bottom-bar reordering · side timers (independent timers per board) · midnight day-rollover enforcement.

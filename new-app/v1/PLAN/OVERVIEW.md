# Planner v1 — Build Plan Overview

> **What this is:** the execution plan for v1 of **Planner** (working title) — a single-board interval-timer app for Linux desktop, built in Flutter/Dart with a pure-Dart engine. Executor = flash-tier model sessions (one part per session), reviewed by the orchestrator model after every part.
> **Decisions of record:** `new-app/v1/OUTLINE.md` (D1–D13). **North-star features (mostly NOT in v1):** `new-app/FINAL-APP-OUTLINE.md`. **UI ground truth:** `new-app/v1/UI-REFERENCE.md` (MultiTimer screenshot descriptions). **Timer-engine reference:** `multitimer-spec/SPEC/engine.md` (semantics to mirror; terminology differs — see CONVENTIONS §1).

## v1 in one sentence

A transparent, dark-themed Linux app (standard KDE window decoration) that runs a single interval timer on a single board: intervals with durations, auto-finish or manually-complete, nested repeat groups, per-interval end-alert sounds (user-supplied mp3s) + KDE notifications, editable via MultiTimer-style editors with undo.

## Structure

Same shape as the decompile plan: phases → parts; **one part = one executor session**, self-contained, ends verifiable. Parts within a phase are ordered; do not start a part whose prereqs aren't green.

| Part | Title | Verifies via |
| --- | --- | --- |
| P0.1 | Toolchain + monorepo scaffold | `flutter build linux` + `dart test` green |
| P0.2 | Desktop shell prototype (transparency/fonts/tray) | **User visual check** (checkpoint 1) |
| P1.1 | Engine data model + persistence | engine unit tests |
| P1.2 | Flatten: nested defs → interval instances | engine unit tests |
| P1.3 | Execution state machine (virtual clock) | engine unit test battery |
| P1.4 | Events, end-alerts, terminal-state logging | engine unit tests |
| P2.1 | Adapters + app wiring (clock/store/notify/sound) | smoke test on desktop |
| P3.1 | Board screen (dial, states, start/pause) | widget tests + visual |
| P3.2 | Board controls (list-jump, reset, skip) + end behavior | widget tests + **user checkpoint 2** |
| P4.1 | Timer editor shell, chips, toolbar, undo | widget + engine tests |
| P4.2 | Group interactions (degradable part) | widget tests + visual |
| P4.3 | Interval editor + alert selector | widget tests |
| P5.1 | Alert firing pipeline (sound + KDE notification) | desktop smoke + user check |
| P6.1 | Hardening, acceptance walkthrough, docs | **User acceptance** (checkpoint 3) |

## Review protocol

- Executor completes a part → commits → writes a completion report (CONVENTIONS §6).
- Orchestrator reviews code + report before the next part starts; user checkpoints at P0.2, P3.2, P6.1.

## Risk register (each has a designed mitigation)

1. **Linux transparency** — proven GTK recipe owned by our runner code; risk burned in P0.2 before any real UI.
2. **Group editor interactions** — hairiest UI; P4.2 is isolated with a documented degrade path to flat-groups-only if it stalls (engine keeps nesting regardless).
3. **KDE notification click/actions** — click-to-focus is required (P5.1); **action buttons are explicitly OUT of v1** (parked in FINAL-APP-OUTLINE.md; stretch item in P6.1 only, droppable).
4. **Toolchain install** — Flutter SDK + `clang` + `gtk3` headers missing on this machine; P0.1 installs them; sudo may require the user (BLOCKERS protocol).

## Environment notes (as of 2026-10-27)

- Present: cmake, ninja, gcc, pkg-config, java, rg. **Missing: flutter/dart SDK, clang, gtk3 dev headers.**
- Fonts (ProLisa, MonoLisa) live in `/usr/local/share/fonts/p/` — copied into the app as gitignored assets (public repo; licensed fonts stay local).
- Repo: `~/HalfaCloud/Jumperpedia/Projects/Repos/multitimer`, branch `main`, remote `github.com/ejumper/multitimer`. All v1 code lives under `new-app/`.

## Out of scope for v1 (do not build even if trivial-looking)

Sync · webapp · Android · widgets · calendar/multi-board UI · dated intervals · completion-state UI (schema groundwork only) · no-duration intervals · per-interval repeat row (superseded by single-interval groups) · custom color picker/palette (6 hardcoded swatches) · alert warnings/pre-alerts/vibration/repeat policies · notification action buttons · import/export · app naming/package-id.

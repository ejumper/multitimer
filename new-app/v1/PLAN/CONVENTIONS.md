# Planner v1 — Build Conventions

Binding rules for every executor session. Read fully before starting any part.

## 1. Terminology (deviations here have caused real confusion — follow exactly)

| Term | Meaning |
| --- | --- |
| **Planner** | This app (working title). |
| **Interval definition** (`IntervalDef`) | An interval as *authored* in the editor: name, color, duration, finish method, end alert. |
| **Interval instance** | One concrete playback occurrence produced by flattening definitions through groups/repeats. |
| **Finish method** | `auto-finish` (next interval starts when duration ends) or `manually complete` (pauses at zero until the user advances). **Never say "autocomplete"** — that collides with the MultiTimer SPEC's *autocompletion* (whole-timer auto-reset after finish, a feature we do NOT have). |
| **Trigger method** | `order` or `date`. v1: always `order`; `date` exists in the schema as groundwork only. |
| **Completion state** | `completed` / `not completed`. v1: stored, defaulted, never surfaced. |
| **Terminal state** | How an instance ended: `done` / `cut` / `skipped` / `moved`. Logged from day one. |
| **Group** | Bracket over ≥1 consecutive intervals (single-interval groups ARE allowed) with a repeat count N = **total passes** (2 = runs twice). Nesting uncapped. |
| **Reset** | Timer returns to not-started showing total planned. Run state is never persisted across app restarts; definitions are. |

The MultiTimer SPEC describes the *original app* and uses its own vocabulary ("instrument", "autocompletion", "pause between intervals"). Use it as a semantic reference, not a naming or code source.

## 2. Layer rules (the architecture is the product)

```
new-app/
  packages/planner_engine/   # PURE Dart: no flutter imports, no OS access
  apps/planner/              # Flutter Linux app: UI + adapters
```

- `planner_engine` must never import `flutter*` or `dart:io`, and never call `DateTime.now()`. It receives a `Clock`, a `Store`, and event sinks via constructor injection.
- A **purity test** in the engine package enforces this by scanning imports (write it in P1.1; keep it green forever).
- All timer math is computed from **wall-clock anchors** (`snapshot(now)`), never accumulated ticks. See `multitimer-spec/SPEC/engine.md` §2, §5 for the reference semantics.
- The app never computes timer state itself; it renders `snapshot(now)` and forwards user intents to the engine.

## 3. Test-driven development

- Engine: **every behavior lands as a test first**; the virtual clock makes time free (simulate "1:59:58" instantly). Target: 100+ engine tests by P1.4. Zero-crossing edge rules from SPEC engine.md §2/§3 (pause legality, finish-armed-only-in-future, last-instant pause) each get named tests.
- UI: widget tests for state rendering and interactions; no pixel-perfect goldens (transparency makes them flaky) — assert on structure/text.
- A part is NOT done unless its DoD commands pass: `dart test` (engine) and `flutter test` (app) both green from repo root.

## 4. Git discipline

- One branch per part off `main` (`part/P1.3` etc.), one squash-merge commit per part minimum; commit messages `v1 P1.3: execution state machine`.
- Never commit: fonts, sounds, build artifacts (`.gitignore` owns this).
- Orchestrator reviews before merge to `main`.

## 5. When blocked or uncertain

- **Stop, don't improvise** on: scope creep, architecture changes, dependency choices not listed in the part, or any failing DoD after 3 genuine attempts. Write it up in `new-app/v1/PLAN/BLOCKERS.md` (format inside) and end the session. Same protocol as the decompile plan.
- UI details not specified in the part or `UI-REFERENCE.md`: pick the boring MultiTimer-faithful option, note the decision in the report.
- Never "temporarily" weaken a test to go green.

## 6. Completion report (end of every part, appended to the part file)

```
## Report — <part id> — <date>
Status: done | done-with-notes | blocked
Tests: <counts engine/app, all green?>
Decisions made: <bullets>
Deviations from part file: <bullets or none>
Suggested tweaks to later parts: <bullets or none>
How to verify by hand: <commands / steps>
```

## 7. Style

Dart/Flutter defaults (`dart format`, `flutter analyze` clean). Boring, idiomatic, commented-where-non-obvious. English UI copy. Dates ISO. IDs are UUIDv4 strings.

# Planner v2 — Build Conventions

Binding rules for every v2 chunk. Carries v1's conventions forward (`new-app/v1/PLAN/CONVENTIONS.md`) with v2's additions. Read fully before starting any chunk.

## 1. Terminology (v1 terms still bind — never say "autocomplete")

| Term | Meaning |
| --- | --- |
| **Plan** | A timer as authored: intervals + groups. One kind of thing everywhere — routine, task list, project, template. |
| **Library** | The folder-organized home of plans that aren't bound to a day (was "Tasks" + "Templates"). A **folder** is just organization; a "template" is a folder. |
| **Day** | A calendar date bound to a plan. Shows a **placeholder** (the rule-resolved library plan) until first write. |
| **Placeholder** | A day's unmaterialized plan: read-only views render through it; nothing is stored. |
| **Materialize / lazy fork** | The first *write* to a day (plan edit, checkmark, adjustment, run start) copies the plan (as it stands) into the day's own timer, **completion marks cleared**. Lived days are frozen; library edits reach future days by arrival. |
| **Wall** | A dated interval (trigger = time-of-day on its day). Fires as **interrupt & resume** — NOT the North Star's jump-&-skip (top-insertion made that unusable). |
| **Suspend slot** | Single slot holding the wall-interrupted item (position + remaining + state). The suspended item is NOT logged and NOT `cut`; it resumes after the wall. |
| **Open interval** | No duration (nullable). Order+Open+manual = task-like. Semantics: instant at its turn → alarm + hold (exactly like a zero-duration manual interval). *Auto-finish requires a duration.* |
| **Timed / Dated / Open** | Named shapes: order+duration / date-triggered / order+no-duration+manual. |
| **Completion mark** | `completed` / `not completed` on the plan item — the *work*. Orthogonal to terminal state (the *execution*). Marks are cleared by **reset** and by **fork**; they persist on in-place library plans (task lists). |
| **Fly past** | The run instant-skip over a pre-completed item when reached (logs `skipped`; the mark stands). |
| **Checklist mode** | A plan whose intervals are all Open defaults to: checked items sink below a completed section after a 3-second window, show/hide completed toggle. Overridable. Chain mode (default otherwise) never moves items. |
| **Terminal state** | `done` / `cut` / `skipped` / `moved`. v2 uses `done`, `skipped`, `cut` (a wall cutting a running wall; genuine truncations). `moved` stays unused. |
| **Reset** | Rewind the run to start **and clear all completion marks**, adjustments, and the suspend slot. Uniform on every timer. |
| **Group** | v1 definition stands. v2 rule: **dated intervals can't be added to groups that repeat; repeat counts can't be set on groups containing dated intervals** (v2 forbids it — revisit never or v3+). |

## 2. Layer rules (unchanged — the architecture is the product)

- `packages/planner_engine/` is PURE Dart: no `flutter*`, no `dart:io`, no `DateTime.now()`. Clock/Store/sinks injected. The purity test stays green forever.
- All time math from **wall-clock anchors** (`snapshot(now)`), never tick accumulation — this now also covers **wall firing**: a wall whose trigger passes during a sleep/clock jump fires at the next settle, flagged late (consistent with the past-due rule).
- The app renders `snapshot(now)` and forwards intents; the engine owns all semantics (completion, walls, forks' source-of-truth behavior is app/store-side but the mark rules are engine rules).

## 3. The model rules worth re-reading before touching the engine

1. **Checkbox**: current → finish + complete (advance); future → mark only (fly past on reach); any mark toggleable anytime.
2. **Hold resolution**: Enter = completed + advance; the **"not completed"** button = not-completed + advance. A hold never advances by time alone.
3. **Auto-finish** runs its course → auto-completes → advances. `cut`/`skipped` → not-completed default (mark overridable).
4. **Walls**: interrupt & resume (suspend slot, resumed in its prior state with its remaining time) · held item auto-resolves completed on wall takeover · wall-vs-wall = later cuts earlier (`cut`) · past-due fires at start flagged late · run ends with a wall pending = paused countdown to it · dated + no duration = alarm + hold at its trigger.
5. **Overlaps**: blocked at capture only (P5). Editor-produced overlaps resolve by rule 4 (later cuts earlier).

## 4. Test-driven development

- Engine: **every behavior lands as a named test first** (v1's discipline). The P1.3/P1.4 matrices are the deliverable as much as the code. `dart test` + `flutter test` green from `new-app` via `bash scripts/test.sh` at all times (was 145 engine + 146 app at v2 kickoff — it only grows).
- UI: widget tests on structure/text/keys (no goldens). Reuse the v1 patterns: bounded `pump()` (the board ticker hangs `pumpAndSettle`), keyed `IconButton` descendant assertions (private widget types can't be cast), append-before-helper-classes in test files.
- Each chunk states its **pinned tests**; a chunk is not done until they exist and the suite is green.

## 5. Git & workflow discipline

- One commit per chunk: `feat: v2 <P#.#> — <title>` style; **never backticks in commit messages** (use `git commit -F`). Changelog entry per meaningful change via the changelog tool (never mentioned to user).
- User verification per phase from the release bundle (`apps/planner/build/linux/x64/release/bundle/planner`, rebuilt via `scripts/build.sh`); `scripts/install.sh` only after the final acceptance.
- Docs that must stay current as work lands: `new-app/v1/keymappings.md` (keymap changes ride with their chunk), README when user-visible behavior changes.
- Absolute repo paths in shell work (`/home/ejumps/HalfaCloud/Jumperpedia/Projects/Repos/multitimer`).

## 6. When blocked or uncertain

- **Stop, don't improvise** on: scope creep, architecture changes, dependency choices not in the plan, or a chunk failing after 3 genuine attempts. Write it in `new-app/v2/PLAN/BLOCKERS.md` and raise it — same protocol as v1.
- UI details the outline left as "open to ideas": pick the boring option already chosen in-plan (month-grid date picker; no New-Event quick action), note the decision, move on.
- Micro-decisions flagged in chunk files (marked `TODO(micro)`) are decided at the chunk's implementation with a stated default — surface any that feel wrong during phase review.
- Never "temporarily" weaken a test to go green.

## 7. Style

v1 §7 stands: `dart format`, analyze clean, boring idiomatic code, English UI copy, ISO dates, UUIDv4 ids. New-row rendering should be *extracted* from the editor's interval row (P2.1), not duplicated.

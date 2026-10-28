# New App — North Star Outline

> **What this is:** the complete feature vision for the app we're building toward — a record of *what it does*, so we don't forget decisions. It is **not** v1 scope (that's a separate, later discussion) and intentionally contains **no UI/visual design**.
> **Provenance:** timer-engine behavior modeled on MultiTimer (`../multitimer-spec/SPEC/` — see engine.md, features.md); day-plan model inspired by Sorted³'s locked-events + flexible-tasks pattern, unified into a single interval chain.
> **Status:** draft for tweaking — 2026-10-27, rev 2 (interval reframed as 4 core properties).

---

## 1. Object model

**Hierarchy:** Calendar → Days → each day owns a **board** → boards hold **interval timers** (and other items, §6).

- A day's board starts with one interval timer: **the day chain** — the day's plan.
- *(Assumed, confirm)* boards may also hold **side timers** that run independently of the chain (e.g. laundry timer while the day chain runs).
- Free (non-calendar) boards exist too — §6.

**The interval** is the atomic unit. It carries **four core properties**, each with exactly two states:

| # | Property | States |
|---|---|---|
| 1 | **Completion state** | `completed` / `not completed` |
| 2 | **Duration** | has a `duration` / `no duration` |
| 3 | **Finish method** | `auto-finish` (next interval starts automatically) / `manually complete` (user must move past it) |
| 4 | **Trigger method** | `order` (starts when the previous interval finishes) / `date` (starts at its set date & time) |

- Intervals also carry other properties (name, board, color/icon, alerts, sub-structure — below), but the four above define engine behavior.
- Common combinations get names for quick use: **Timed** = order + duration · **Dated** = date-triggered · **Open** = order + no duration + manually complete.
- Completion state is about *the work* (did it actually happen — the checkbox); terminal states (§2.3) are about *execution* (how the interval ended). Independent of each other.

**Other interval properties:**

- label (+ color/icon, MultiTimer-style — extent TBD)
- optional alerts: on interval start and/or end
- optional **sub-structure:** a duration interval may itself be a full interval timer (warm-up / run×N / walk / cooldown, with labels + per-sub-interval alerts) — the day list stays flat, nesting lives inside the block

## 2. Execution semantics (the engine)

### 2.1 Flow
- Order-triggered intervals cascade: projection = day start + cumulative durations. Change anything (reorder, resize, skip) → everything downstream re-projects instantly.
- **Transitions are governed by the finished interval's finish method:** an auto-finish interval starts the next one the moment it ends; a manually-complete interval holds the chain until the user moves past it.
- If the next interval is date-triggered and its time hasn't arrived, the chain waits (paused, counting down to it) regardless.

### 2.2 Walls (date-triggered intervals)
**The rule:** when a date-triggered interval's time arrives, the chain jumps to it *regardless of state*:
- mid-duration interval → **cut** there (actual < planned)
- paused (incl. held on a manually-complete interval) → auto-resumes into the date-triggered one
- never-run intervals in between → **skipped**
- chain finished early before a wall → paused, showing countdown to it

Date-triggered interval details:
- Overlapping date-triggered intervals: the later wall cuts the earlier one; flagged at plan time.
- When a date-triggered interval ends (duration elapsed, or the user moves past it), the next interval's finish method applies (§2.1).
- Works even if the day was never started: the wall still fires and becomes current; earlier intervals skipped *(confirm — open question)*.

### 2.3 Terminal states
- **done** — ran its course / user moved past it
- **cut** — a wall ended it early; actual-vs-planned preserved
- **skipped** — never ran
- **moved** — relocated elsewhere (§3)
- Terminal states record execution; completion state (§1) records the work. Both logged.

### 2.4 Warnings & repairs
- **Pre-wall warning:** configurable lead time per date-triggered interval ("in 10m you'll be 20m over").
- **Rebalance-to-fit:** shrink a flowing stretch before a wall to fit — proportional, weighted, or skip-flagged-optional-first.
- **Remainder actions on cut:** move remainder → after next wall / end of day / tomorrow / drop. One tap.

### 2.5 Live editing
- The running chain stays editable: add / reorder / resize / remove intervals ahead of now (schedule overlay).

### 2.6 Plan vs reality
- **Day origin:** a start time per day (or "start now"). Before start, the day is a *projection*; starting makes it *reality*.
- Retroactive correction supported (mark "actually started at 1:15") — MultiTimer precedent.

### 2.7 Engine foundations (inherited from MultiTimer recon)
- Live state computed from **wall-clock anchors**, never tick counting.
- Alarms survive backgrounding and reboot (foreground service, boot re-arm, alarm-clock-class delivery).
- Every run logged with actuals → run history per interval/day.

## 3. Moving work around
- Move a single interval to another day — quick.
- Bulk: move **all unfinished items** from one day to another (rollover).
- Cut-remainder one-tap actions (§2.4).
- Completion state travels with a moved interval (a not-completed item stays not-completed where it lands).

## 4. Templates
- Any timer (or board) can be **saved as a template**.
- Templates can be **pasted into any day's board**.
- A **default template** can be set — auto-inserted into new days.
- (Recurring date-triggered intervals — weekly class, etc. — likely lives here; parked §8.)

## 5. Quick capture
- Add a date-triggered interval to a day at a time, calendar-app fast (the "quick event" interaction).

## 6. Free boards (beyond the calendar)
- Boards **not bound to a date**:
  - **Projects** — steps as intervals (typically order + no duration + manually complete); work as free time allows; pause and resume across days, pick up where left off.
  - **Lists** — pure checklists (groceries): items + completion state, no time machinery.
- Share mechanics with day boards where sensible (templates, items, completion state).

## 7. Platforms & sync
- Targets: **Android + Linux desktop**.
- **Local-first**; sync between devices is ours to design (no MultiTimer precedent — it's local-only). Nextcloud file-sync a candidate.
- Design goal: no account / no cloud dependency required. *(Confirm as hard requirement.)*

## 8. Parked / deferred (not forgotten)
- UI & visual design; calendar navigation.
- Recurring date-triggered intervals; day-routines beyond default template.
- Chains crossing midnight; late-night trigger times.
- DST / timezone edge cases.
- Widgets, wearables.
- Which MultiTimer tool types survive as side timers (stopwatch? counter? clock? pomodoro→just a template?) — inventory decision during v1 scoping.
- Import/export formats; stats/insights beyond the run log.
- App name.

## 9. Open questions
1. Day board: exactly one day chain + independent side timers? (assumed)
2. Completion-state defaults: auto-set `completed` when a duration interval runs its full course? Default after cut/skip? (assumed: cut/skip/moved → not completed)
3. Wall firing on a never-started day (§2.2) — confirm behavior.
4. Date-triggered interval ends early → chain continues per next interval's finish method (assumed).
5. Sync mechanism (§7).
6. v1 scope — next discussion.

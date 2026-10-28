# New App — North Star Outline

> **What this is:** the complete feature vision for the app we're building toward — a record of *what it does*, so we don't forget decisions. It is **not** v1 scope (that's a separate, later discussion) and intentionally contains **no UI/visual design**.
> **Provenance:** timer-engine behavior modeled on MultiTimer (`../multitimer-spec/SPEC/` — see engine.md, features.md); day-plan model inspired by Sorted³'s locked-events + flexible-tasks pattern, unified into a single interval chain.
> **Status:** draft for tweaking — 2026-10-27. Origin: design discussion between ejumper & pi.

---

## 1. Object model

**Hierarchy:** Calendar → Days → each day owns a **board** → boards hold **interval timers** (and other items, §7).

- A day's board starts with one interval timer: **the day chain** — the day's plan.
- *(Assumed, confirm)* boards may also hold **side timers** that run independently of the chain (e.g. laundry timer while the day chain runs).
- Free (non-calendar) boards exist too — §7.

**The interval** is the atomic unit, defined by two orthogonal rules:

| | ends after duration | ends manually |
|---|---|---|
| **starts on flow** | **Timed** — "groceries, 1h" | **Open** — "dishes until done" |
| **starts at clock time** | **Pinned+duration** — "meeting 2:00–3:30" | **Pinned+manual** — "study w/ friend @2pm until done" |

- Named presets in UI: Timed, Dated (pinned), Open. All four matrix cells valid.
- *(Naming note: the manual-end type was called "checked" in discussion; collides with the completion checkbox §3 — rename pending.)*

**Every interval carries:**

- label (+ color/icon, MultiTimer-style — extent TBD)
- **advance mode, set per interval:** auto (next starts immediately) or pause (chain waits for me)
- optional alerts: on interval start and/or end
- optional **sub-structure:** a Timed interval may itself be a full interval timer (warm-up / run×N / walk / cooldown, with labels + per-sub-interval alerts) — the day list stays flat, nesting lives inside the block
- completion checkbox (§3)

## 2. Execution semantics (the engine)

### 2.1 Flow
- Flowing intervals cascade: projection = day start + cumulative durations. Change anything (reorder, resize, skip) → everything downstream re-projects instantly.
- Advance per interval: **auto** chains on; **pause** halts the chain at that boundary until resumed.

### 2.2 Walls (pinned intervals)
**The rule:** when a pinned interval's time arrives, the chain jumps to it *regardless of state*:
- mid-flow interval → **cut** there (actual < planned)
- paused (incl. paused on an Open interval) → auto-resumes into the pinned one
- never-run intervals in between → **skipped**
- chain finished early before a wall → paused, showing countdown to the wall

Pinned-interval details:
- Overlapping pinned intervals: the later wall cuts the earlier one; flagged at plan time.
- When a pinned interval ends (duration elapsed or manual done), the next interval's own advance mode applies.
- Works even if the day was never started: the wall still fires and becomes current; earlier intervals skipped *(confirm — open question)*.

### 2.3 Terminal states
- **done** — ran its course / manually confirmed finished
- **cut** — wall ended it early; actual-vs-planned preserved
- **skipped** — never ran
- **moved** — relocated elsewhere (§5)
- Distinct from completion checkbox (§3), which records *whether the work actually happened*.

### 2.4 Warnings & repairs
- **Pre-wall warning:** configurable lead time per pinned interval ("in 10m you'll be 20m over").
- **Rebalance-to-fit:** shrink a flowing stretch before a wall to fit — proportional, weighted, or skip-flagged-optional-first.
- **Remainder actions on cut:** move remainder → after next pinned / end of day / tomorrow / drop. One tap.

### 2.5 Live editing
- The running chain stays editable: add / reorder / resize / remove intervals ahead of now (schedule overlay).

### 2.6 Plan vs reality
- **Day origin:** a start time per day (or "start now"). Before start, the day is a *projection*; starting makes it *reality*.
- Retroactive correction supported (mark "actually started at 1:15") — MultiTimer precedent.

### 2.7 Engine foundations (inherited from MultiTimer recon)
- Live state computed from **wall-clock anchors**, never tick counting.
- Alarms survive backgrounding and reboot (foreground service, boot re-arm, alarm-clock-class delivery).
- Every run logged with actuals → run history per interval/day.

## 3. Completion tracking
- Every interval has a **checkbox**: checked = I actually did it. Unchecked but advanced past = preserved knowledge it wasn't really completed.
- *(Open: auto-check when a Timed interval runs its full duration? Default state after cut?)*

## 4. Moving work around
- Move a single interval to another day — quick.
- Bulk: move **all unfinished items** from one day to another (rollover).
- Cut-remainder one-tap actions (§2.4).

## 5. Templates
- Any timer (or board) can be **saved as a template**.
- Templates can be **pasted into any day's board**.
- A **default template** can be set — auto-inserted into new days.
- (Recurring pinned intervals — weekly class, etc. — likely lives here; parked §9.)

## 6. Quick capture
- Add a pinned interval to a day at a time, calendar-app fast (the "quick event" interaction).

## 7. Free boards (beyond the calendar)
- Boards **not bound to a date**:
  - **Projects** — steps as Open items (optional durations); work as free time allows; pause and resume across days, pick up where left off.
  - **Lists** — pure checklists (groceries): items + checkboxes, no time machinery.
- Share mechanics with day boards where sensible (templates, items, checkboxes).

## 8. Platforms & sync
- Targets: **Android + Linux desktop**.
- **Local-first**; sync between devices is ours to design (no MultiTimer precedent — it's local-only). Nextcloud file-sync a candidate.
- Design goal: no account / no cloud dependency required. *(Confirm as hard requirement.)*

## 9. Parked / deferred (not forgotten)
- UI & visual design; calendar navigation.
- Recurring pinned intervals; day-routines beyond default template.
- Chains crossing midnight; late-night pinned times.
- DST / timezone edge cases.
- Widgets, wearables.
- Which MultiTimer tool types survive as side timers (stopwatch? counter? clock? pomodoro→just a template?) — inventory decision during v1 scoping.
- Import/export formats; stats/insights beyond the run log.
- App name.

## 10. Open questions
1. Day board: exactly one day chain + independent side timers? (assumed)
2. Auto-check semantics for full-duration runs and cuts (§3).
3. Wall firing on a never-started day (§2.2) — confirm behavior.
4. Pinned+duration ends early → chain flows per next interval's advance mode (assumed).
5. Sync mechanism (§8).
6. v1 scope — next discussion.

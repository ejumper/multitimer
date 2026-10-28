# Planner v1 — Acceptance Walkthrough (Checkpoint 3)

Run this top-to-bottom on your KDE desktop, no workarounds. Check each box; note
anything that misbehaves in the "Issues" section at the bottom. This document
doubles as the P5.1 focus-state verification.

Setup: `cd ~/HalfaCloud/Jumperpedia/Projects/Repos/multitimer/new-app/apps/planner && flutter run -d linux`
(or `build/linux/x64/release/bundle/planner`). Put at least one mp3 in
`~/.local/share/planner/sounds/` (e.g. `ding.mp3`) before step 4.

## 1. Boot & edit

- [ ] App launches to the board: transparent window, your KDE decoration, board name header.
- [ ] Right-click the dial → editor opens ("Interval timer", ✕ / Done).
- [ ] Rename the timer (label field) and pick a color (swatch row) → Done → board reflects it (dial ring color).

## 2. Build a day

- [ ] `+` → interval editor: name `warmup`, 5 min, auto-finish ON, End Alert = your mp3 → back → chip appears.
- [ ] `+` → `run`, 30 min, auto-finish ON, no alert.
- [ ] `+` → `break`, 7m 30s, **auto-finish OFF** (manually complete), End Alert = your mp3.
- [ ] `+` → `cooldown`, 5 min, auto-finish ON.
- [ ] `+` → `plan`, 1 min, auto-finish ON (this one will be a single-interval group).
- [ ] Select `warmup` + `run` (selection circles) → Group → stepper modal opens → set 2 → OK → bracket shows `2`.
- [ ] Select `plan` alone → Group → OK → single-interval bracket appears.
- [ ] Select a group bracket → Ungroup (then re-group if you want it back) — outermost-only behavior.
- [ ] Nested check (optional): group a group; tap the inner bracket → nothing happens; ungroup the outer → inner bracket now responds.
- [ ] Drag a chip across a group boundary (long-press drag into/out of a bracket).
- [ ] Undo each of the above with the undo arrow; Done.

## 3. Run it

- [ ] Click the dial → starts (running readout: total remaining, `mm:ss`, `N. label`).
- [ ] Click → pause (`| PAUSED`); click → resume. **Space bar does the same.**
- [ ] List button → overlay lists all instances (N. label | duration, current highlighted); tap a later row → jumps there and closes.
- [ ] Skip `>` advances; Reset `✕` asks "Reset timer?" (Cancel does nothing; Reset returns to the planned readout).

## 4. Alerts (the P5.1 matrix — repeat with the window focused, unfocused, and closed-to-tray)

- [ ] Interval with an alert reaches zero → **mp3 plays + KDE notification appears** (title = timer name, body = `N. label`) — in all three window states.
- [ ] Click the notification → Planner window comes to front.
- [ ] Manually-complete interval (`break`) reaches zero → alert + notification fire, board shows `00:00` + pulsing "tap to continue".
- [ ] Tap-to-continue (or the notification's **Continue** button) advances to the next interval.

## 5. Finish & restart

- [ ] Let the chain run to the end → board returns to the fresh planned readout (no zombie state).
- [ ] Quit from the tray menu → app exits cleanly (sound stops).
- [ ] Relaunch → all definitions intact (name, colors, intervals, groups), timer reset to not-started.

## 6. Housekeeping

- [ ] Second launch of the app focuses the existing window (no second window).
- [ ] `PLANNER_SMOKE=1 ./planner` prints SMOKE_OK + a test notification.
- [ ] `PLANNER_SMOKE=alert ./planner` prints SMOKE_OK + fires a real end-of-interval alert.

## Issues found

(free-form — what broke, what looked wrong)

-

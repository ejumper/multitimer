# SPEC — Timer engine (core document)

Synthesized from `FINDINGS/engine.md` (behavior + citations) and `FINDINGS/background-and-alerts.md` (delivery + playback). This is the behavioral contract a rebuild must satisfy.

## 1. Tool types

Ten user-facing tools; seven are backed by instrument classes, three are board-level elements:

| Tool | Persisted id | Behavior summary |
| --- | --- | --- |
| Countdown | `g5vs` | Preset duration; optional auto-repeat (unlimited, Countdown-only) or autocompletion (auto-reset after finish) — mutually exclusive; optional pre-finish warning; delayed/retroactive start |
| Quick | `y9wg` | No preset duration — duration chosen at start ("Start for…"); then like Countdown minus repeat/delay |
| Interval | `ok9y` | Sequential interval list with **nestable groups carrying repeat counts**; optional pause between intervals; per-interval name/color/duration/start-alert/end-alert/repeat; skip-next; schedule overlay while running |
| Pomodoro | `hz3x` | Work / break / long-break cycle with repeat count (Pomodoro technique) |
| CountUp | `s5lu` | Counts up from a chosen start point; supports scheduled notices with alerts |
| Stopwatch | `e2kh` | Fractions-of-a-second count-up; lap/split recording; **no pause** |
| Counter | `m6zp` | Step counter: mode (increase & decrease), initial value, step, optional final value; ±/set/reset |
| Clock | `pc5x` | Board element: time zone, time format, dial style |
| Container | `t5ql` | Board element embedding timers from other boards, fully operatable in place |
| Buttons | `he5b` | Board element: up to 3 labeled buttons, each binding multiple commands **(PRO)** |

Each instrument keeps a live state snapshot (phase, remaining/elapsed, interval index, worked time, extra time) recomputed from **wall-clock anchors** (see §5) — never from tick counting.

## 2. State machine

Common phase set: **NONE → (PREP_TIME) → WORK → PAUSE ↔ WORK → COMPLETE / OVER_COMPLETE → NONE**. Interval adds a **WAIT** phase (between-interval pause). Events: user actions {START, DELAY, RESET, PAUSE, RESUME, START_INTERVAL, SKIP_INTERVAL, INCREASE, DECREASE, LAP, COMPLETE} and scheduled events {ON_START (delayed start), ON_FINISH (zero), ON_START_INTERVAL/ON_FINISH_INTERVAL, ON_WARNING (pre-alert), ON_FINALIZE (autocompletion point), ON_SNOOZE}.

Countdown transitions (the reference machine; all types are structurally identical with the per-type action set of engine §1.2):

| From | Event | Guard | Effect → To |
| --- | --- | --- | --- |
| NONE | START | duration > 0 | clear anchors; if start-moment > now → schedule ON_START and emit DELAY; else run → WORK |
| scheduled | ON_START | — | enter WORK at the scheduled moment |
| WORK | PAUSE | state == WORK | freeze remaining; re-schedule alarms; → PAUSE |
| PAUSE | RESUME | state == PAUSE | recompute from new anchor; → WORK |
| any ≠ NONE | RESET | — | clear anchors; **record history event {elapsed, completed = elapsed ≥ total}**; → NONE |
| WORK/PAUSE/COMPLETE | ADD_TIME(±) | one of those | shift ticker end; re-schedule; → unchanged (new end) |
| WORK | (no event) | remaining hits 0 | ON_FINISH alarm → alert; → COMPLETE (OVER_COMPLETE once past) |
| COMPLETE/OVER_COMPLETE | ON_FINALIZE | autocompletion ON | auto-RESET (with completed history event) → NONE |
| any | config edit | — | apply; if schedule-affecting keys changed → re-schedule pending alarms |

Edge rules: PAUSE is legal only from WORK; ON_FINISH is only armed while the computed finish is in the future; ADD_TIME is the dedicated ±adjust while running; deleting a running timer cancels its alarms and tombstones its history. Autocompletion arms one extra ON_FINALIZE at finish + `max(alertLead, 5 s) − 1 s` (code) — the help doc rounds this to "10 seconds" (G-E3). Auto-repeat (Countdown only) emits recurring finish-interval alarms instead of a single ON_FINISH: each zero-crossing starts the next cycle. Retroactive starts (past start date) enter mid-cycle and skip missed repeats.

## 3. Zero-crossing and alert flow

1. **ON_WARNING** (lead time from alert config) fires the pre-alert ("makes 3 final beeping sounds" in docs; lead-driven in code).
2. **ON_FINISH** fires the alert per config (§6) and flips state to COMPLETE; the timer then either auto-repeats, auto-completes (ON_FINALIZE → reset), or stays awaiting manual action.
3. History is recorded **on stop/complete** (the reset that ends the run), as {elapsed, completed}; interval runs also persist an interval-snapshot event plus per-interval details. **(PRO)** Pro flushes every event to history; free keeps only the newest.
4. Counter has no zero-crossing; its "events" are value changes recorded as int-valued history entries.

## 4. Linking & sequencing (the honest answer)

**There is no autonomous timer-to-timer chaining** — the engine's zero-crossing pipeline has exactly three consumer kinds (autocomplete, notices, workspace refresh); none starts another timer. Sequencing is achieved by:

1. **Commands / Buttons** **(PRO)** — command = {target instrument, condition ∈ {inactive, active, running, waiting, completed}, action}. Action vocabulary: Tap (per-state smart action), Run, Start, Start-for <duration>, Delay <duration>, Reset, Pause, Continue, Next Interval, Lap, Plus, Minus, Set value (counter), Get value (read-only). Execution is **manual** (button press or public-intents API call): a command fires only if the target's current state-set contains the condition; Start on an active target = reset-then-start; one action per tool per button; Buttons tool acts on its own board; Clock/Buttons targets are excluded. "Tap" resolves per state — e.g. Countdown WORK→Pause, PAUSE→Continue, COMPLETE→Reset; Stopwatch WORK→Lap.
2. **Delayed start** — future (or past) start moments schedule an ON_START alarm; the retroactive path resumes mid-cycle.
3. **Container** — operate other boards' timers from the current board.

No pause propagation, no rule engine, no cycles: commands never fire on timer events.

## 5. Background operation & accuracy

- **Wall-clock anchoring**: instruments store start/pause anchors + accumulated segments as epoch millis; elapsed = accumulated + (now − segment start). Process death and reboots lose nothing; there is no foreground tick dependency and no `elapsedRealtime` state.
- **Alarms**: one AlarmManager alarm per instrument — only the single earliest pending event, re-armed after each delivery; events sharing the exact timestamp coalesce. Mode is user-selectable: exact alarms (`setExactAndAllowWhileIdle`, degrading to `setAndAllowWhileIdle` when unblessed on API 31+) or the system **alarm-clock API** (default; Doze-exempt, shows the alarm icon). Early firings (<2 s) are re-scheduled rather than delivered. All pending schedules persist in prefs; **after reboot** a job re-registers every instrument's next event within 1–10 s and rebuilds countdown notifications. Deleting a timer cancels by intent.
- A change outbox DB exists but has no consumer — no sync leaves the device.

## 6. Alert delivery

- Config per event: sound, vibration, play duration, repeat policy (**None / Times(N) — N repeats one minute apart / Long — ~5 minutes total**). Defaults: built-in "Short alarm" (1 s), no vibration, no repeat.
- Playback: MediaPlayer from built-in resource / imported file / TTS-generated file **(PRO)**; loops while the play duration exceeds the track; hard auto-stop. Vibration = 500 ms pulse repeating every second. Audio stream user-selectable (Media / Alarm / Notification); when DND is active and policy access is granted, the app lifts DND and restores it afterwards. On Android 16+ playback is hosted in a `mediaPlayback` foreground service; earlier versions play without one.
- Notifications: silent "Alarm" (HIGH) and "Status" (LOW) channels + a silent service channel; ongoing countdown notifications use a self-ticking chronometer view (no per-second alarms — a low-frequency state alarm updates content); alert notifications carry actions Reset / Restart / Snooze (9 min) / Close and are suppressed while the app is foreground. The USE_FULL_SCREEN_INTENT permission is declared but never used.
- Delivery diagnostics (device/scheduling state snapshots) are recorded locally for the support bundle; nothing uploads.

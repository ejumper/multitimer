# SPEC — Feature inventory

Complete feature list by area. **Status**: `documented` = fully specified in this SPEC with findings backing; `partial` = specified with named unknowns (→ `gaps.md`); `gap` = not recoverable from this build. `**(PRO)**` = gated behind the Pro upgrade (one-time purchase or subscription; see Features → Licensing). Citation keys (`data-model §1.2`, `engine §3.0`, …) point into the FINDINGS docs.

Audit note: every `documented` item below carries at least one findings citation; the audit trail is in `README.md`.

## 1. Tools (the ten elements)

| # | Feature | Status | Backing |
| --- | --- | --- | --- |
| 1.1 | **Countdown timer** — preset duration, auto-repeat option, autocompletion option, delayed/retroactive start, pre-alert (warning), per-alert sound/vibration/repeat config | documented | engine §1.1, §2–3; data-model §5 |
| 1.2 | **Quick timer** — duration chosen at start ("start for…"), then as Countdown minus repeat/delay | documented | engine §1.1 |
| 1.3 | **Interval timer** — ordered interval list, **nestable groups with repeat counts**, per-interval label/color/duration/start-alert/end-alert/repeat, pause-between-intervals option, next-interval skip, schedule overlay while running | partial | engine §1.1 (surface + actions documented); internal phase algebra gapped (G-E1) |
| 1.4 | **Pomodoro timer** — work/break/long-break cycle with repeats, same controls as Interval | partial | engine §1.1; internals gapped (G-E1) |
| 1.5 | **CountUp timer** — counts up from a chosen point; scheduled notices with per-notice alerting | documented | engine §1.1, §2 |
| 1.6 | **Stopwatch** — count-up with lap/split recording; no pause | documented | engine §1.1 |
| 1.7 | **Counter** — step counter with mode (increase & decrease), initial value, step, optional final value; set/±value/reset; history | documented | engine §1.1; settings-sounds-pro §1.2 |
| 1.8 | **Clock** — world clock with time zone, time format, dial style choices | partial | ui §1.0 (editor + time-zone picker); dial-style options gapped (G-U3 adjacent) |
| 1.9 | **Container** — board element that embeds and operates timers living on other boards | documented | engine §4.1; ui §2.0 |
| 1.10 | **Buttons element** — up to 3 buttons, each with label/color and multiple commands (target + condition + action) **(PRO)** | documented | engine §4.2–4.3; guides-buttons doc |

## 2. Boards & workspace

| # | Feature | Status | Backing |
| --- | --- | --- | --- |
| 2.1 | Boards = named pages of tools; horizontal paging with page dots; **1 board free, unlimited (PRO)** | documented | settings-sounds-pro §3.2 (vn2.v); ui §2.0 |
| 2.2 | **12 instruments per board free; unlimited (PRO)** | documented | settings-sounds-pro §3.2 (j0) |
| 2.3 | Board layouts: default grid, adaptive matrix, flexible (free-form position/size/overlap) — **flexible (PRO)** | partial | data-model §4.1 (Matrix elements); gate site unresolved (G-P1) |
| 2.4 | Board menu: rename, edit (layout mode), add timer, Web Share, Export, Undo Last Action, Copy board, Delete board | documented | ui §2.0 (IMG_6217); data-model §4.1 |
| 2.5 | Move timers between boards; rearrange boards; duplicate board with timers | documented | ui §2.0; data-model §5 |
| 2.6 | Undo ("Cancel last changes") = compensating DB transaction; **3 trials free, unlimited (PRO)** | documented | data-model §2.0; settings-sounds-pro §3.2 (fw3) |
| 2.7 | Lock a timer (prevents accidental interaction) | documented | ui §2.0 (IMG_6221 menu); engine §2.5 |

## 3. Timer operation (engine)

| # | Feature | Status | Backing |
| --- | --- | --- | --- |
| 3.1 | Start / pause / resume / reset per type; per-state quick actions ("Tap" smart action) | documented | engine §2.3 (T1–T9), §2.5 |
| 3.2 | Add/subtract time on a running (or paused/finished) timer | documented | engine §2.3 (T6) |
| 3.3 | Skip to next interval (Interval/Pomodoro) | documented | engine §1.2 (NEXT_INTERVAL), §2.5 |
| 3.4 | Lap / split (Stopwatch) | documented | engine §1.2 |
| 3.5 | Zero-crossing: warning pre-alert → finish alert → auto-repeat (Countdown only) **or** autocompletion (auto-reset) — mutually exclusive | partial | engine §3.0; autocompletion delay discrepancy G-E3 |
| 3.6 | Delayed / retroactive start: wait-time, start-date, end-date tabs; past starts resume mid-cycle with missed repeats accounted | documented | engine §4.1; background §2.1 (early-fire reschedule) |
| 3.7 | Edit duration/config while running (re-schedules pending alarms) | documented | engine §2.3 (T9) |
| 3.8 | Deleting a running timer cancels its alarms and tombstones history | documented | engine §2.4; data-model §1.3 |
| 3.9 | Commands — remote actions on other tools: target + condition (inactive/active/running/waiting/completed) + action (Tap, Run, Start, Start-for, Delay, Reset, Pause, Continue, Next Interval, Lap, Plus, Minus, Set value, Get value); fire only when condition matches; manual execution only (no autonomous chaining) **(PRO)** | documented | engine §4.2–4.3 |
| 3.10 | Public intents API — exported receiver `com.multitimer.api`: action/value/board/instrument/model/state extras drive the same command pipeline | documented | engine §4 pointer; background §6.0 (br_i9fa) |

## 4. Alerts & notifications

| # | Feature | Status | Backing |
| --- | --- | --- | --- |
| 4.1 | Per-event alert config: sound, vibration, play duration, repeat policy (None / N×minutes / Long ≈5 min) | documented | background §5.0 |
| 4.2 | Sound sources: 2 built-ins (1 s, 6 s), device sounds via picker **(PRO)**, text-to-speech sounds **(PRO)** | documented | settings-sounds-pro §2.0; background §5.0 |
| 4.3 | Alert playback: MediaPlayer (loops if play-time exceeds track), 500 ms vibration loop, user-selectable audio stream (Media/Alarm/Notification), auto DND-lift with policy permission | documented | background §5.0 |
| 4.4 | Alert notifications with actions (Reset / Restart / Snooze(9 min) / Close); suppressed while app foreground | documented | background §4.0 |
| 4.5 | Persistent countdown notifications (ongoing, self-ticking chronometer), master toggle | documented | background §4.0 |
| 4.6 | Scheduling exactness: user-selectable exact-alarm vs system alarm-clock mode; Doze-proof; per-timer single-next-event alarms, re-armed each fire | documented | background §2.0 |
| 4.7 | Reboot recovery: alarms re-registered from persisted schedule; countdown notifications rebuilt | documented | background §3.0 |

## 5. History

| # | Feature | Status | Backing |
| --- | --- | --- | --- |
| 5.1 | Per-timer run log grouped by date with totals and per-interval details | documented | data-model §1.3, §1.6; ui §2.0 |
| 5.2 | **Free tier keeps only the newest event; Pro stores full history (PRO)** | documented | engine §3.0 (dk2) |
| 5.3 | **CSV export, one file per timer, share sheet (PRO)** | documented | data-model §4.2 |
| 5.4 | Retention setting (forever / N years / N days) via daily maintenance | documented | settings-sounds-pro §1.3 |

## 6. Import / export / sharing

| # | Feature | Status | Backing |
| --- | --- | --- | --- |
| 6.1 | **Board export/import as `.mtb` (XML, MIME `application/multitimer`), cross-platform Android↔iOS (PRO)** | partial | data-model §4.1 (envelope + vocabulary documented; per-field schemas for all types not enumerated, G-D2) |
| 6.2 | Web Share — share boards via web link | partial | ui §3.0 (`c_webshare_dialog_content`, string `eyf0`); flow internals gapped (G-P1 adjacent) |
| 6.3 | Diagnostics bundle (`logs.zip`) with device/scheduling state | documented | background §2.1; data-model §1.7 |

## 7. Home-screen widgets

| # | Feature | Status | Backing |
| --- | --- | --- | --- |
| 7.1 | Three widget sizes (1×1, 2×1, 2×2): progress ring + value + name + corner buttons (open, actions menu, settings) | documented | ui §4.0 |
| 7.2 | In-widget action menu (per-widget configured actions), per-widget config activities, transparent quick-start dispatcher | documented | ui §4.0; settings-sounds-pro §1.6 (`jy6a`) |

## 8. App shell & settings

| # | Feature | Status | Backing |
| --- | --- | --- | --- |
| 8.1 | First-run welcome/onboarding; not re-shown afterward | documented | ui §1.0; settings-sounds-pro §1.6 (`nz67`) |
| 8.2 | Side drawer: boards list (+ add/edit), Commands section (deprecated Buttons predecessor), History, Settings | documented | ui §2.0 |
| 8.3 | Single-timer view with control row + tabbed panels (Buttons / History / Note / Stats) | documented | ui §2.0 |
| 8.4 | Settings: Appearance (Light/Dark/system), Controls (double-tap, quick-timer naming), Alert Settings (stream/volume/persistent/full-screen/alarm-mode/DND), Sounds library, History settings, Optional (wait animation), Deleted-data restore | documented | settings-sounds-pro §1.0; ui §1.0 |
| 8.5 | Editors: shared property-row system (name/icon/color/duration/switch/number), color picker with saved palette, fixed icon set (42), interval entry editor, alert/repeat/note editors, duration keypad | documented | ui §1.0, §3.0; settings-sounds-pro §4.0 |
| 8.6 | In-app alerts suppressed while foreground; wake hint when locked (no full-screen intent — declared but unused) | documented | background §4.0 |
| 8.7 | Localization: resource-based, 10 languages in distribution splits; English default | documented | WORK/APK-INFO.md; ui §5.0 |

## 9. Licensing

| # | Feature | Status | Backing |
| --- | --- | --- | --- |
| 9.1 | Single Pro license via Play Billing: monthly subscription, annual subscription, one-time purchase (product ids `by8t`, `o5bs`, `n2ck`, `v9mx`) **(PRO)** | documented | settings-sounds-pro §3.1 |
| 9.2 | Gating mechanics: runtime flag, 25 check sites (list in settings-sounds-pro §3.2); premium banner (dismissible); limit dialogs; Pro screen with purchase restore **(PRO)** | documented | settings-sounds-pro §3.2–3.4 |
| 9.3 | Ten gated areas: boards, instruments/board, flexible layout, Buttons, history+CSV, export/import, undo, add-time/value config, custom+TTS sounds, interval repeat=0 **(PRO)** | partial | settings-sounds-pro §3.3 (8/10 code-cited; flexible-layout & export/import gates inferred from docs + UI, G-P1) |

## 10. Explicitly absent on Android (present on iOS or website)

iOS Live Activity, iCloud Sync, "Use as System Alarm" per-timer toggle, app badge setting, Siri shortcuts, URL scheme, color themes beyond Light/Dark, template gallery, Stepped/Lap timer tool types — none exist in this APK (ui §2.0 cross-check; settings-sounds-pro §1.5; exclusions §0). Sources: `REFERENCE/index.md` iOS sections; screenshots IMG_6213/6216.

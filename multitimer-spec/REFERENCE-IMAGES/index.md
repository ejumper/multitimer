# REFERENCE-IMAGES index

User-provided screenshots of the **iOS** MultiTimer app (iPhone, dark mode, v5.x era UI, Oct 2026).
Ground truth for the conceptual UI; the Android app (our target) implements the same
information architecture with Material-style chrome. Platform-specific rows (Live Activity,
iCloud Sync, "Use as System Alarm", Apple Watch note) are iOS-only.

| File | Screen / content |
| --- | --- |
| IMG_6212.PNG | Interval-timer **editor**, top half: color swatch row + custom color, "Add label" field, toggles "Pause between intervals" / "Autocompletion", "Intervals" toolbar (add, group, ungroup, duplicate, delete, reorder) with interval chips (break 7m30s, Cards 15m) grouped under repeat-count badge "8", "Extra info" picker (Overall time) |
| IMG_6213.PNG | Interval-timer **editor**, bottom half: Extra info (Overall time), Units of Time (days/hours/minutes/seconds), "Add Time Buttons" (Default >), toggle "Use as System Alarm" (iOS-only wording), toggle "Live Activity" (iOS-only), Note >, History >, Delete |
| IMG_6214.PNG | **Board screen, single-timer container view**: big circular dial (03H:00M00), control row (start, restart, pause, interval-list, close, lock), caption ">> 1. break - 7m 30s" (next interval), page dots (board pages), top bar = boards side-menu button, board name "tmp", board gear button |
| IMG_6215.PNG | **Boards side menu** (drawer over board): BOARDS list (Timers, Counters, tmp; current = bullet) + Edit; COMMANDS section: "Reset all timers"; History >; Settings > |
| IMG_6216.PNG | **Settings sheet**: Appearance (Blue theme), Badge (Active timers), Display Settings (Uses system auto-lock settings); Controls (Customize timer controls), Alert Settings (Customize timer end alerts), Sounds (Manage alert sounds and the default beeper), iCloud Sync (No Account) [iOS-only], History (Customize timer history settings), Optional settings |
| IMG_6217.PNG | **Board gear menu** (popover on board screen): Rename board, Edit board, Add a timer, Web Share, Export, Undo Last Action (disabled), Copy board, Delete board (destructive) |
| IMG_6218.PNG | **Counters board**: one Counter dial (green ring, value 0, − / + tap zones) + one Buttons element ("BUTTON" pill) on same board page; page dots |
| IMG_6219.PNG | **Counter editor**: color swatches + "Add label"; Mode = "Increase & decrease"; Initial value 0; Step 1; Final value None; "Add Value Buttons" (Default >); History >; DELETE |
| IMG_6220.PNG | **Color picker screen** (pushed): preview swatch + mini dial preview, hue/saturation gradient area, brightness slider, saved-color row (+, swatches, delete) |
| IMG_6221.PNG | **Instrument long-press menu** (over board): Start, Delay, Lock, History, Single view, Edit |
| IMG_6222.PNG | **Interval (per-interval) editor**: color swatches, label "break", duration display "7m 30s" + D/H/M/S keypad (± , 0, backspace), rows: Start Alert (No alerting), End Alert (illegal), Repeat (1), Note > |
| IMG_6223.PNG | **Alert editor** (per-event): Sound (illegal >), Vibration toggle, iOS note about Apple Watch sounds, Warning toggle ("Makes 3 final beeping sounds"), Repeat (None >); play (preview) button top-right |
| IMG_6224.PNG | **Alert editor**, silent variant: Sound = Silent, Vibration toggle (same screen, different state) |
| IMG_6225.PNG | **Interval editor with repeat-count stepper popover**: "− 2 +" over the Repeat row (OK) |
| IMG_6226.PNG | **Interval list overlay** (interval-list control on running interval timer): "1. break — 7m 30s", "2. Cards — 15m", … numbered schedule list |
| IMG_6227.PNG | **Delayed start dialog** ("DELAYED START"): tabs Wait time / Start date / End date; Wait-time tab = duration display + D/H/M/S keypad; START button |
| IMG_6228.PNG | **Delayed start dialog**, Start-date tab: iOS date wheel (date / hour / minute / AM-PM), START |
| IMG_6229.PNG | **Interval-timer editor**, intervals with a **group** (repeat count "1" bracket) containing 4 chips (Study (Anki) 1h, Jobs 3h, Study (Labs) 2h, Study 3h) plus ungrouped chips (Run 50m, get ready for bed 10m, movie 1h10m, read (tech) 20m, read (fiction) 20m); Intervals toolbar above |
| IMG_6230.PNG | Same as 6229 with a **nested group** (repeat "1" inside repeat "1" bracket wrapping 5 chips) — groups nest |
| IMG_6231.PNG | Same editor, **collapsed/compact edit mode**: per-row delete (−) buttons + drag handles; grouped row shows "1 | 5 intervals | 9h 10m"; Autocompletion toggle ON |
| IMG_6232.PNG | **New interval editor** (empty): color swatches, "Add label", duration "0" + keypad, Start Alert (No alerting), End Alert (illegal), Repeat (1), Note > |
| IMG_6233.PNG | **Note editor**: pushed blank text screen with system keyboard |
| IMG_6234.PNG | **History screen**: date sections ("OCT 22, 2026" + TIME column), per-run rows (start time + `*` elapsed e.g. `* 37m 41s`), per-day TOTAL row; share (export) + edit buttons top-right |

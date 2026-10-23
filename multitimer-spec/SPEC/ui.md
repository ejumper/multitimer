# SPEC — UI

Condensed from `FINDINGS/ui-structure.md` (screen map with layout-level citations) and `REFERENCE-IMAGES/index.md` (23 iOS screenshots — conceptual ground truth; platform-specific rows flagged). No Jetpack Navigation: navigation is activities + drawer + popups + dialogs.

## 1. Screen map

| Screen | Class (role) | Presents | Navigation |
| --- | --- | --- | --- |
| Main workspace | `MainActivity` | Toolbar (drawer ☰ / board name / gear ⚙) + horizontally paged board pages (page dots) + per-state dynamic action toolbar; drawer (boards+Edit, Commands, History, Settings); board gear popover (Rename, Edit board, Add a timer, Web Share, Export, Undo, Copy board, Delete board) | → everything below; drawer switches boards |
| Single timer view | `MTSingleViewActivity` | One instrument full-screen + control row + tabbed panels (Buttons / History / Note / Stats) | from board long-press ("Single view") or alert tap |
| Instrument editor | `MTInstrumentEditorActivity` (shell: Cancel/Done) | Per-type property lists: Countdown / Quick / Interval / Pomodoro / CountUp / Stopwatch / Counter / Clock / Buttons / Container | → property sub-screens (below) |
| └ Interval entry editor | `MTIntervalTimerEntryActivity` | One interval: color, label, duration keypad, Start Alert, End Alert, Repeat stepper, Note | from Interval editor |
| └ Alert editor / Repeat editor / Note editor / Color picker / Icon picker / Time-zone / Duration keypad / CountUp notices / Add-Time or Add-Value buttons / Button item editor | dedicated activities | alert config (sound/vibration/warning/repeat); repeat policy; free text; gradient+saved palette; 42-icon fixed set; D/H/M/S keypad; notices list; preset-button lists; one button's label/color/commands | from editor tree |
| History | `HistoryActivity` | Instruments → date-grouped sessions (start time, `*elapsed`, per-day TOTAL) → details; limit banner (free); share (CSV) + edit actions **(PRO storage/export)** | from drawer / single view / editors |
| Settings | `AlertSettingsActivity`, `ControlsSettingsActivity`, `HistorySettingsActivity`, `ExtraSettingsActivity`, `DeletedDataActivity` (+ shared page shell) | Alerts: stream (Media/Alarm/Notification), volume, persistent notifications, full-screen/wake, alarm-mode, DND access. Controls: double-tap, quick-timer naming. History: retention. Optional: wait animation. Deleted-data restore. iOS-only rows (iCloud Sync, Live Activity, Use-as-System-Alarm, Badge) absent on Android | from drawer |
| Sounds library | `SoundsActivity` (+ `TextToSpeechActivity`) | Built-ins (2) + device sounds **(PRO)** + TTS creation **(PRO)** | from Settings |
| Pro screen | `ProVersionActivity`/Fragment | Feature list, offers, purchase/restore **(PRO)** | from limit dialogs/banner |
| Welcome | `WelcomeActivity` | First-run onboarding (never re-shown) | → Main |
| Notice screen | `MTInstrumentActivity` | Alerting instrument full-screen (from notification tap; falls back to next event within 1 h) | from notifications |
| Widget config ×3 + quick-start | `AW{Mini1,Mini2,Single}SettingsActivity`, `AWQuickStartActivity` | Timer binding + action list per widget | from launcher widget add |

Board-embedded instruments render through one shared custom view (dial for timers, ring counter, button pills, container host, clock), with per-state overlay quick-actions and a long-press menu (Start / Delay / Lock / History / Single view / Edit). Interval timers show a numbered schedule overlay while running.

## 2. Editor composition (information architecture)

Shared property-row system: name, icon (42 fixed), color (gradient picker + saved palette), duration (custom D/H/M/S keypad with ± and backspace), switches, numeric stepper, big-text values. Interval editor adds the intervals toolbar (add / group / ungroup / duplicate / delete / reorder), interval chips, **group brackets with repeat counts that nest**, a compact edit mode (per-row delete + drag handles, collapsed "N intervals, total" row), "Extra info" and "Units of Time" pickers. Counter editor: Mode / Initial / Step / Final + Add-Value Buttons **(PRO row)**. Countdown-family editors carry Add-Time Buttons **(PRO row)**, auto-repeat, autocompletion, alert config, note, history link.

## 3. Dialogs & menus

Duration/time entry, add-time, set-counter-value, text input, numeric stepper, export (.mtb **(PRO)**), Web Share, board-layouts chooser, instrument picker (containers/commands targets), styled popup menus (board gear, instrument long-press, interval list, element actions), progress overlay, page dots. All inventoried with one-line purposes in `FINDINGS/ui-structure.md` §3.0.

## 4. Home-screen widgets

Three resizable widgets — mini (1×1), wide (2×1), single (2×2): circular progress, big value (live chronometer or text), timer name, corner buttons (open app, icon, actions menu, settings); per-widget action list; config activities; transparent one-tap dispatcher; Material 3 dynamic-color theming; updates driven by the app scheduler (`updatePeriodMillis=0`).

## 4a. Screenshot cross-reference (REFERENCE-IMAGES/index.md → screens above)

| Screenshots | Screen(s) |
| --- | --- |
| IMG_6212, IMG_6213, IMG_6229–6232 | Interval-timer editor (property rows, intervals toolbar, groups/nesting, compact edit mode, new-interval entry) |
| IMG_6214, IMG_6221, IMG_6226, IMG_6227, IMG_6228 | Board-embedded timer view, long-press menu, interval schedule overlay, delayed-start dialog (both tabs) |
| IMG_6215, IMG_6217 | Side drawer; board gear menu |
| IMG_6216 | Settings hub (iOS-only rows flagged) |
| IMG_6218, IMG_6219 | Counters board (counter + Buttons element); Counter editor |
| IMG_6220 | Color picker |
| IMG_6223, IMG_6224 | Alert editor (two states) |
| IMG_6225 | Repeat-count stepper |
| IMG_6233, IMG_6234 | Note editor; History screen |

## 5. Theming & display

Material 3 Day/Night base (`Theme.App`), Light/Dark/system choice, dynamic-color accents for widgets; custom palette attributes (background primary, board background, content primary, premium accent); single bundled condensed typeface for digits. iOS color themes ("Blue theme") have no Android counterpart.

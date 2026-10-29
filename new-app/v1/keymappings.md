# Planner v1 — Keyboard Mappings

The complete keyboard reference (written after the keyboard-navigation
work; if the app and this file disagree, the app is a bug — or this file
is stale, check the changelog).

## Global rules

- **Sections**: most screens are split into focus areas. `Tab` / `Shift+Tab`
  cycle forward/backward; `Ctrl+Home` / `Ctrl+End` jump to the first/last
  section. Focus is shown by a thin ring (circular on round buttons).
- **Arrows / Home / End / Enter** act within the focused section.
- **Typing rule**: while a text field has focus, arrows/Home/End and
  Ctrl+Z/Ctrl+C belong to the field (normal text editing). The exit combos
  (Tab, Escape, Ctrl+S …) and the duration-box keys always work.
- **Escape** always leaves: dialogs cancel, sub-screens go back, the board
  opens the timer editor.

## Board

| Key | Action |
| --- | --- |
| Space / media play-pause | context action: start / pause / resume; at a held manual zero = continue |
| ← → | move between the control buttons (interval selector, reset, next) |
| Home / End | first / last control button |
| Enter | activate the focused button |
| Tab | open the interval selector |
| Delete | open the reset confirmation |
| Ctrl+→ | next interval |
| Escape | open the timer editor |

## Interval list overlay

| Key | Action |
| --- | --- |
| ↑ ↓ | move between intervals |
| Home / End | first / last interval |
| Enter | jump to the focused interval (and close) |
| Escape | close, no change |

## Reset confirmation

| Key | Action |
| --- | --- |
| ← → | Cancel ↔ Reset (focus starts on Cancel) |
| Enter | activate the focused button |
| Escape | Cancel |

## Repeat stepper (group repeat count)

| Key | Action |
| --- | --- |
| ← → | −1 / +1 |
| Ctrl+← → | −10 / +10 |
| Enter | OK (confirm) |
| Escape | Cancel (no change) |

## Timer editor

Sections (Tab order): **top row (✕/Done) · color picker · name · button
row · intervals**.

| Key | Action |
| --- | --- |
| Escape / Ctrl+S | Done (commit + close) |
| Shift+Escape | ✕ (discard all edits + close) |
| Ctrl+Z | undo |
| Ctrl+C | duplicate the focused item (or its selection) |
| Delete | delete the focused item (or its selection) |
| Ctrl+N | add interval |
| Ctrl+G | group the selection (needs a contiguous selection) |
| Ctrl+Shift+G | ungroup the selection |
| Space | toggle the focused selector circle / pick the focused color |

- **Top row / button row**: ← → move between buttons (skipping greyed-out
  ones), Enter activates, Home/End first/last (color picker and button row).
- **Name**: type to edit (focus arrives on Tab; Enter re-focuses).
- **Intervals grid** — rows are visual rows; three vertical tracks:
  **selectors**, **group columns**, **rectangles**.
  - ↑ ↓ move along the current track ("up from test 3 selects test 4").
  - ← → walk the grid in reading order (a group's circle → its group
    column → its content).
  - Enter/Space on a **selector** toggles it; Enter on a **group column**
    opens the repeat stepper; Enter on a **rectangle** opens that
    interval's editor.

## Interval editor

Sections (Tab order): **back · color picker · name · auto-finish ·
duration · End Alert**.

| Key | Action |
| --- | --- |
| Escape | back (commit + close) |
| Enter (auto-finish) | toggle |
| Space (auto-finish) | toggle |
| ← (auto-finish) | auto-finish OFF |
| → (auto-finish) | auto-finish ON |
| ↑ ↓ (duration) | ±1 unit (Ctrl: ±10) |
| Enter / Shift+Enter (duration) | cycle hr → min → sec (wraps) |
| ← → (duration) | same as Enter / Shift+Enter |
| Enter (End Alert) | open the End Alert selector |

Duration boxes are **always editable** — the active box holds the caret
(select-all on arrival, typing replaces) and the focus ring follows it;
there is no separate "enter the box" step.

## End Alert selector

| Key | Action |
| --- | --- |
| Tab / Shift+Tab | back button ↔ alert list |
| ↑ ↓ | move between alerts |
| Home / End | first / last alert |
| → | play the focused alert's preview |
| ← | stop the preview |
| Enter | select the focused alert (auto-closes) |
| Escape | back (same as the back button) |

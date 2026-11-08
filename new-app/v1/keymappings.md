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
| Space / media play-pause | context action: start / pause / resume; at a held manual zero = completed (✓) |
| ← → | move between the control buttons (adjust, reset, next) |
| Home / End | first / last control button |
| Enter | activate the focused button |
| Alt+↑ / Alt+↓ | jump to the previous / next interval (running stays running at the target, a paused run sits paused-ready) |
| Delete | open the reset confirmation |
| Ctrl+→ | next interval |
| Escape | open the timer editor |

**Right-click an interval row** in the list = jump straight to that
interval — the target is the first occurrence at or after the current
one, else the last (jump-to-same restarts it). Direct jump, no
confirmation step. The old interval-list overlay (Tab / the list button)
is retired (v2 P2.3); Tab cycles sections like everywhere else and does
nothing on the board's single section.

## Bottom bars + quick actions

Every page renders its own pill bar. The MAIN bar (the board root), left
to right: **Settings · Calendar · Library · New Event**.

Right click is a button's **quick action** — only where one is defined
(left click always does the normal page jump):

| Button | Right click (quick action) |
| --- | --- |
| Settings | nothing — no quick action is defined |
| Calendar | opens the Calendar on the **non-default view**: week when the default-view setting is month, month when it is week |
| Library | saves the currently open timer into a folder (the folder picker opens; nothing navigates) |
| New Event | nothing — no quick action is defined |

## Plan / day board bar

The plan board's and day board's bar, left to right: **home · back ·
new item · delete mode · checklist toggle · show/hide completed ·
defaults menu**. Day boards additionally reveal prev/next-day chevrons
at the window edges on hover (outside the reading column).

- **home** — today's day board (or the plan the Home setting names);
  **back** — one level back.
- **new item** — opens the interval editor in CREATE mode for this plan:
  fill it in and back saves the new interval into the plan (a blank form
  saves nothing).
- **delete mode** — the button turns red while armed. Tap an interval
  row → confirm dialog → the item is deleted from the plan (a group
  takes its whole subtree); Cancel or clicking away keeps it. The mode
  stays armed across deletes until the button is tapped again. While
  armed, the row's completion circle doesn't toggle — the tap asks to
  delete instead; right-click still jumps to the interval.
- **checklist toggle** — switches checklist/chain mode (the tooltip
  names the current one); **show/hide completed** — the completed
  section's visibility; **defaults menu** — the plan's default rules
  (make default for all days / a weekday / a month day).

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
| Alt+↑ / Alt+↓ | move the focused interval + the selected intervals as
  ONE contiguous block, past one row (a non-contiguous selection gathers
  together behind the focus; passing a group header row moves the block
  into / out of the group) |
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

Sections (Tab order): **back · color picker · name · toggles (auto-finish ·
Duration · Time) · duration boxes · time boxes · End Alert** — the box
sections exist only while their toggle is ON (Duration ON shows `hr · min
· sec`, Time ON shows `hh · mm`).

| Key | Action |
| --- | --- |
| Escape | back (commit + close) |
| Enter / Space (toggles) | toggle the focused toggle (auto-finish / Duration / Time) |
| ← / → (toggles) | focused toggle OFF / ON |
| ↑ ↓ (toggles) | move between auto-finish → Duration → Time |
| ↑ ↓ (duration) | ±1 unit (Ctrl: ±10) |
| Enter / Shift+Enter (duration) | cycle hr → min → sec (wraps) — the ONLY cycling keys |
| ← → (duration) | move the TEXT CURSOR inside the box (they belong to the field) |
| ↑ ↓ (time) | ±1 unit (Ctrl: ±10), clamped to 0–23 / 0–59 |
| Enter / Shift+Enter (time) | cycle hh → mm (wraps) |
| ← → (time) | move the TEXT CURSOR inside the box |
| Enter (End Alert) | open the End Alert selector |

Auto-finish is **grayed out and forced OFF while Duration is OFF** (the
engine contract: auto-finish requires a duration). Turning **Time** ON
inside a repeating group is refused with the exclusivity reason (dated
intervals never repeat).

Duration boxes are **editable while Duration is ON** — the active box
holds the caret (select-all on arrival, typing replaces) and the focus
ring follows it; there is no separate "enter the box" step. The time
boxes work the same way (no seconds box — 24-hour wall time).

## End Alert selector

Focus starts in the alert list.

| Key | Action |
| --- | --- |
| Tab / Shift+Tab | back button ↔ alert list |
| ↑ ↓ | move between alerts |
| Home / End | first / last alert |
| → | play the focused alert's preview |
| ← | stop the preview |
| Enter | select the focused alert (auto-closes) |
| Escape | back (same as the back button) |

**v2 P2.2 — hold decisions (while an interval holds at zero):**
- `Enter` (or `NumpadEnter`) = **completed** (✓) — supersedes button activation at holds only
- `N` = **not completed** (✗) — the same as the control row's decision button
- `Space` / the tap-to-continue area = completed (same as Enter)
- Elsewhere Enter keeps its button-activation role (the arrow-walk model).

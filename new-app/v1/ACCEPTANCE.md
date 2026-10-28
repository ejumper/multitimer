# Planner v1 — Acceptance Walkthrough (Checkpoint 3)

Run this top-to-bottom on your KDE desktop, no workarounds. Check each box; note
anything that misbehaves in the "Issues" section at the bottom. This document
doubles as the P5.1 focus-state verification.

Setup: `cd ~/HalfaCloud/Jumperpedia/Projects/Repos/multitimer/new-app/apps/planner && flutter run -d linux`
(or `build/linux/x64/release/bundle/planner`). Put at least one mp3 in
`~/.local/share/planner/sounds/` (e.g. `ding.mp3`) before step 4.

## 1. Boot & edit

- [x] App launches to the board: transparent window, your KDE decoration, board name header.
- [x] Right-click the dial → editor opens ("Interval timer", ✕ / Done).
- [x] Rename the timer (label field) and pick a color (swatch row) → Done → board reflects it (dial ring color).
	- Note: changing timer color requires a restart.

## 2. Build a day

- [x] `+` → interval editor: name `warmup`, 5 min, auto-finish ON, End Alert = your mp3 → back → chip appears.
	- works except mp3 doesn't play, see below for details
- [x] `+` → `run`, 30 min, auto-finish ON, no alert.
- [x] `+` → `break`, 7m 30s, **auto-finish OFF** (manually complete), End Alert = your mp3.
- [x] `+` → `cooldown`, 5 min, auto-finish ON.
- [x] `+` → `plan`, 1 min, auto-finish ON (this one will be a single-interval group).
- [x] Select `warmup` + `run` (selection circles) → Group → stepper modal opens → set 2 → OK → bracket shows `2`.
	- Group rendering issue, see below for details
- [x] Select `plan` alone → Group → OK → single-interval bracket appears.
- [x] Select a group bracket → Ungroup (then re-group if you want it back) — outermost-only behavior.
- [x] Nested check (optional): group a group; tap the inner bracket → nothing happens; ungroup the outer → inner bracket now responds.
- [x] Drag a chip across a group boundary (long-press drag into/out of a bracket).
	- needs work, see below
- [x] Undo each of the above with the undo arrow; Done.

## 3. Run it

- [x] Click the dial → starts (running readout: total remaining, `mm:ss`, `N. label`).
- [x] Click → pause (`| PAUSED`); click → resume. **Space bar does the same.**
- [x] List button → overlay lists all instances (N. label | duration, current highlighted); tap a later row → jumps there and closes.
- [x] Skip `>` advances; Reset `✕` asks "Reset timer?" (Cancel does nothing; Reset returns to the planned readout).

## 4. Alerts (the P5.1 matrix — repeat with the window focused, unfocused, and closed-to-tray)

- [x] Interval with an alert reaches zero → **mp3 plays + KDE notification appears** (title = timer name, body = `N. label`) — in all three window states.
	- notification shows, but sound doesn't play, see below
- [x] Click the notification → Planner window comes to front.
- [x] Manually-complete interval (`break`) reaches zero → alert + notification fire, board shows `00:00` + pulsing "tap to continue".
- [x] Tap-to-continue (or the notification's **Continue** button) advances to the next interval.

## 5. Finish & restart

- [x] Let the chain run to the end → board returns to the fresh planned readout (no zombie state).
- [ ] Quit from the tray menu → app exits cleanly (sound stops).
	- works, but it causes a crash notification to display, obviously this isn't a crash, so its annoying to get that notification
- [x] Relaunch → all definitions intact (name, colors, intervals, groups), timer reset to not-started.

## 6. Housekeeping

- [x] Second launch of the app focuses the existing window (no second window).
- [x] `PLANNER_SMOKE=1 ./planner` prints SMOKE_OK + a test notification.
- [x] `PLANNER_SMOKE=alert ./planner` prints SMOKE_OK + fires a real end-of-interval alert.

Board UI: /tmp/pi-clipboard-b3c9008b-e1cd-45ad-a3eb-a2be1c5d34cc.png


# Bugs

## The time is just slightly oversized
notice that the overall time just slightly overlaps with the ticks, it just needs to be slightly smaller so it doesn't overlap with it. Notably not an issue when the timer is running, only when its in its non-started state, but is an isue when its paused.
- /tmp/pi-clipboard-69875868-3768-4500-8b94-f092ea0fce57.png

## Circular highlight on a square button
- /tmp/pi-clipboard-67e3c21b-9ddb-4788-8640-963cc69cb267.png
- proposed fix: no background on the buttons, keep the circular background appear as the hover effect, but make the circle just a touch bigger

## Slight delay on the transition to the interval timer editor screen
on the transition between the board to the timer editor, timer starts the animation, but on what I assume is the last frame of the animation, it sticks, so for about half a second its just sitting behind the timer editor before it goes away. Along with that, the entire window gets the semi-tranparent background which fades in and gets frozen with the board UI and disappears when the board UI disappears. Notably the reverse animation, exiting the timer editor and returning to the Board, *doesn't* have this issue, it fades the editor out and fades the board back smoothly with no semi-transparent background popping up, no issues. However, the transition between the timer editor and the interval editor *does* have the same exact problem, also only when opening the interval editor, not when closing it. Same for opening the "End Alert" UI, opening it *does* have this bug, closing it does not.

- /tmp/pi-clipboard-e0421dee-1a36-46e8-b39d-f3986e26e0ea.png

## End Alerts don't play

When I press the play button to preview the "End Alerts", nothing happens, the terminal shows the following logs...
```
AudioPlayers Exception: AudioPlayerException(
        UrlSource(url: /home/ejumps/.local/share/planner/sounds/interval-finished1.mp3, mimeType: null),
        PlatformException(LinuxAudioError, Failed to set source. For troubleshooting, see: https://github.com/bluefireteam/audioplayers/blob/main/troubleshooting.md, Invalid URI "/home/ejumps/.local/share/planner/sounds/interval-finished1.mp3". (Domain: gst-resource-error-quark, Code: 3), null)
[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: PlatformException(LinuxAudioError, Failed to set source. For troubleshooting, see: https://github.com/bluefireteam/audioplayers/blob/main/troubleshooting.md, Invalid URI "/home/ejumps/.local/share/planner/sounds/interval-finished1.mp3". (Domain: gst-resource-error-quark, Code: 3), null)
```
Might be a file issue, but they should all be valid mp3s, so I don't know why it happens.

Most importantly alerts also don't play when the interval finishes. 

## Grouped Intervals UI

The grouped intervals UI is all wonky. Its fairly obvious what's wrong from the screenshot, but the repeat number should be centered and the rectangle doesn't have a left side and the top line is wonky. I would also have it have a background the same color as the outline, but semitransparent (the same opacity as the other semi-transparent backgrounds) and not give the number a border or background.
- /tmp/pi-clipboard-31216c1a-8735-4b56-9367-24cca5adff5b.png


# Tweaks

## Reordering intervals
drag to reorder isn't very intuitive
- the length I have to hold before the drag is triggered is way too long
- its very hard to tell where the interval will end up when being dragged somewhere else
how it should work
- dragging should be triggered better, my thought is by movement not by length, something like interval is clicked on + dragged X length, but I'm not a coder, so idk the best way to make this work.
- the entire interval shoul appear to be moved, not just the title.
- instead of letting you drag the interval around anywhere it should only move vertically and reorder as you drag, so if I move the top interval down below the second interval I should see that second interval move up and have the dragged interval slot in below it, if I continue to move it down past the third one again. Same for moving an interval into a grouped interval, I should see it slot in to the group and see it move above the group is moved above it. 
- all in all, it should feel intuitive and be immediately obvious where the interval is being dragged to.

## Color intervals background in the timer editor
the intervals should have a semitransparent background the same color as the interval color that was selected. the opacity should match the "universal semitransparent background" opacity that's used everywhere.

## The semi-transparent background opacity
Opacity is simply too high on the semi-transparent backgrounds, I'd cut it by half

## Blur the background behind overlays
To increase readibility, I'd like to have the blur the UI elements behind them.
- /tmp/pi-clipboard-337e4f8c-6b30-4365-93a9-cb993006ffd0.png

## Auto-finish off by default
Currently when I create a new timer Auto-finish is toggled on by default, it should be toggled *off* by default.

## End Alert placement
The end alert appears to be top aligned, it sits at the very top of the window, every other view is centered in the window, there's no reason for End Alert to be the one exception.
- /tmp/pi-clipboard-7b4d9ceb-23a8-43c2-9f85-449f9eef24c8.png

## New Interval Default Sound
Make the last used sound the default end alert sound appied to newly created intervals

## Notification Expiration
To my knowledge there are two ways a kde notification displays: 1. expires: notification disappears after N time unless the cursor is on the notification 2. remain until closed: notification remains on screen until the user closes it. Its currently the first kind, I would like to make it the second kind, so I either have to close it or hit continue for it to go away.

## Timer Coloring
The timer coloring is incorrect, currently both the outline and the ticks do not update unless the app is restarted. So if I change the color, it remains as the previous color until I restart. The ticks count down the current interval and uses the timer color. Here's how it should work...
- The outline is the color set as the timer color.
- The ticks count the entire timer, not just the current interval
- The ticks are colored by the interval color, so say I have 2 intervals both 1 min in length, one interval is blue, the other is purple, half the ticks should be blue and half the ticks should be purple to indicate which interval I'm on.

- /tmp/pi-clipboard-f5c221ff-f180-4b77-9f6d-a7d29d4addf8.png

## Remove the Board Name
Since there is currently only one board, remove the board name. You can keep the code for future versions, I just don't want to see it.

## Remove light blue and dark blue UI coloring. 
Outside of the colors I have set by the timer and interval color selection, the UI should be greyscale colors only. The exception is "delete" actions should be in red (trashcan icon when not greyed out, "Reset" button and any other "delete" action if there is one.

## group selection semantics
When a group is made, you should not be able to select the individual intervals inside that group. You should still be able to select the interval to edit it in the interval editor, but you shouldn't be able to select them. for the purposes of the timer editor view, they are essentially a joined unit.

## Auto closing "End Alert" UI when a sound is selected
When a sound is selected in "End Alert", it should automatically close and return to the interval editor

## undoing a grouping and making a group tweak
currently undoing a grouping results in the intervals in that group being selected, creating a group results in the group being selected. simply shouldn't happen. there seems to be other weirdness involving selections and undo, but its hard to pin down, take away is though when an action is performed on a selected interval the selection should not remain.

## next interval line below the buttons
on the board UI, you created the next interval line below the buttons, in multitimer this was the button for advancing to the next interval, it was replaced by the ">" button, so this additional line isn't necessary.

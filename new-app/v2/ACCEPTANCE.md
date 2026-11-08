# Planner v2 — Acceptance Walkthrough

Run this top-to-bottom on your KDE desktop from the release bundle:
`cd ~/HalfaCloud/Jumperpedia/Projects/Repos/multitimer/new-app/apps/planner/build/linux/x64/release/bundle && ./planner`
Put at least one mp3 in `~/.local/share/planner/sounds/` first. Check each box;
anything that misbehaves goes in the Issues section at the bottom.

The theme of v2: the dial is gone (the interval LIST is the timer), checking
items is the interaction, plans live in the Library, and days on the calendar
fork their plan lazily (checking/editing a day materializes it; untouched days
follow the routine).

## 1. The list view & completion

- [ ] The board shows the interval list (rows like the editor: name, live
      `<left>/<total>` countdown on the current row, alert label, progress
      fills). No dial anywhere.
- [ ] Check a FUTURE row → it dims; when the run reaches it, it flies past
      (no hold, no sound-block) and the run continues.
- [ ] Check the CURRENT row → it finishes right there, dims, and the run
      moves on (its remaining time is abandoned, by design).
- [ ] A manually-complete interval reaching zero shows `wait` + a pulsing
      border. **Enter** completes it (row checks, run moves on); the
      **remove-done button** (or key `N`) advances it unchecked.
- [ ] After a partially-done run, **Retry missed (n)** appears — pressing it
      re-runs only the un-checked items (the checked ones fly past).
- [ ] **Reset** un-checks every row (and clears +10s tweaks) — this doubles
      as "uncheck the camping list for the next trip".
- [ ] Right-click a row jumps there; Alt+Up/Down steps intervals; the list
      auto-centers the current row and snaps back after you browse.

## 2. Dated intervals (walls)

- [ ] In the timer editor (right-click the board): the **Duration** and
      **Time** toggles sit below Auto-finish. Time ON shows a 24h HH|MM
      setter; Duration OFF greys auto-finish and the row shows `open`.
- [ ] Make an interval dated about 1 minute out, run the timer on another
      interval: at the wall's time the dated one **interrupts** (the
      interrupted row shows its frozen remaining), runs, and on completion
      the plan resumes exactly where it was.
- [ ] A dated interval with NO duration alarms and holds at its time
      ("leaving at 15:00").
- [ ] Pause a run, let a wall's time pass: the wall pulls the run in, and
      after it the paused item is still paused.
- [ ] A dated interval in the editor can't be put in a repeating group (and
      a group with one can't repeat) — both refuse with a reason.
- [ ] Capture a past-due event (New Events, a time earlier today): it saves
      and fires at the day's next run start with the `late` badge.

## 3. Library

- [ ] The bottom bar's **Library** button opens the Library: plan rows (name,
      item count for all-Open plans / total duration otherwise, dates).
- [ ] Folders: create (the `+`), rename (right-click), delete (confirm — it
      names how many plans go with it); drag rows to reorder/move.
- [ ] Tap a plan → its board opens (home/back return); right-click renames;
      the delete-list button arms tap-to-confirm deletion.
- [ ] **Right-click the Library button** on the board: save the open timer
      into a folder — the copy's checks come back cleared.

## 4. Checklist mode

- [ ] An all-Open plan ("groceries": several intervals with Duration OFF)
      behaves like a list: check an item → after **3 seconds** it sinks under
      `Completed` (un-checking within the window keeps it put).
- [ ] The eye button hides/shows the completed section.
- [ ] A plan with any duration never reorders rows (chain behavior).
- [ ] The checklist/chain toggle button overrides the derived mode.

## 5. Default rules

- [ ] On a plan board, the **defaults** menu: "Make the default timer"
      (confirm) · "Default for a day of the week" (picker + repeats-weekly
      switch) · "Default for a day of the month" (picker + repeats-monthly).
- [ ] The menu lists the plan's rules with a remove affordance.

## 6. Calendar & days

- [ ] The **Calendar** button opens week view (7 day rows: name + count);
      the toggle switches month view; the chevrons at the window edges page
      weeks/months (they appear on hover).
- [ ] Today is highlighted; the date-setter (bar button) jumps months and
      highlights a picked day.
- [ ] Tap a day → its board. **Checking or running anything** on it forks the
      day (its plan becomes private); the day's rows look identical before
      and after.
- [ ] Chevrons ON a day board step to the previous/next day (back walks the
      days you stepped through).
- [ ] The lifecycle: check something on TOMORROW, then edit the ROUTINE in
      the Library → the day AFTER tomorrow shows the edited routine while
      tomorrow stays exactly as you planned it.
- [ ] **Home** (any bar) lands on today's day board.

## 7. New Events

- [ ] The **New Event** button opens the editor dated-on: Date boxes (dd mm
      yy) + "Overwrite Default Timer" (off). **Save** puts the event at the
      TOP of the target day's plan; **Save & edit timer** opens that day's
      editor focused on the new interval.
- [ ] Overwrite ON replaces the day's plan with just the event.
- [ ] An overlapping time refuses with a reason until you change it;
      edge-touching times save.

## 8. Settings & shell

- [ ] The **Settings** button opens the page (home-only bar): the
      new-events-override switch · Home (current day or a specific plan) ·
      Interval Options defaults (new intervals seed from these) · Calendar
      default view · the Bottom Bar echo.
- [ ] Home = a specific plan opens that plan's board from every bar.
- [ ] Right-click the **Calendar** button opens the non-default view;
      right-click **Settings**/**New Event** does nothing (by design).
- [ ] The plan board's bar: home · back · new item · delete mode (red → tap a
      row → confirm → the item is gone) · checklist · eye · defaults.

## Issues

(freeform — what misbehaved, what felt wrong, what you want changed)

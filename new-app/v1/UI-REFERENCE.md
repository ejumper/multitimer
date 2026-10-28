## Answer

All 11 screenshots are read and described below at field level. **Note up front:** the screenshots are **dark mode** (near-black background, blue/white text), not "light UI" as stated in the brief — everything else matches the index.md cross-checks. iPhone status bar (time, bell-slash icon, signal/wifi/battery) sits above every screen and is omitted from per-screen descriptions.

---

### 1. IMG_6214.PNG — Board, interval timer, not started (single-timer container view)
Top to bottom:
1. **Top bar**: left = circular-outline button with **3-line hamburger icon** (boards menu); center = board name **"tmp"** (white text); right = circular-outline button with **gear icon**.
2. **Large circular dial**, centered. Outer thin blue ring; inside it a tick-mark ring (radial dashes) mostly blue with scattered purple/magenta ticks. Center readout in blue, large digits: **`03`** with superscript **`H`**, colon, **`00`** with superscript **`M`** and subscript **`00`** (seconds) — i.e. "03H:00M" big, "00" small = 3h00m00s total planned time.
3. **Control row** (6 icon buttons, left→right, no labels): ▷ (play/start), restart (clock with small play arrow), pause (two vertical bars, dimmed/disabled), interval list (bulleted-list icon), ✕ (close), padlock (locked).
4. **Next-interval caption**, blue: **`≫ 1. break - 7m 30s`** (double chevron, then "N. label - duration").
5. **Page dots** near bottom: 3 dots, third active (filled blue).

Dial shows the **total planned time** (3h) before start — since the timer hasn't run, planned = the full sum.

### 2. "Screenshot 2026-10-27 at 8.08.13 PM.png" — Board, running, PAUSED
Same chrome (hamburger / "tmp" / gear; same 6-button control row; same page dots; caption now **`≫ 2. day 12 - 30m`** = next interval). Dial contents top-to-bottom inside the ring (gray outer ring, blue + white tick ring):
1. **Top line, smaller gray text: `6h 44m`** — this is the **total time remaining** in the board. Evidence: intervals still ahead per the list screenshot are 14×15m + 13×30m plus the ~15m left in interval 1 ≈ 6h44m; it is neither total planned (~6h59m) nor total elapsed.
2. **Main line, large white digits: `14:59`** followed by a blue vertical bar and blue **`PAUSED`** — current-interval time remaining + paused state flag.
3. Horizontal divider line.
4. **Bottom line, gray: `1. break`** — current interval number + label.
Ring ticks: elapsed portion white/dimmed, remaining portion blue.

### 3. "Screenshot 2026-10-27 at 8.09.21 PM.png" — Board, running (unpaused)
Identical layout to #2, but main line is just large white **`14:58`** — no bar, no "PAUSED". Top line still **`6h 44m`**, bottom line still **`1. break`**, caption **`≫ 2. day 12 - 30m`**. Confirms: top = total remaining, middle = current-interval remaining (counts down, 14:59→14:58 over one minute), bottom = current interval.

### 4. "Screenshot 2026-10-27 at 8.13.54 PM.png" — Interval list overlay
Same board chrome behind (dimmed); a modal list (rounded dark card, 2/3 of screen height, scrolled so a gray arc of the dial peeks at the right edge). Rows, each `N. label` left, duration right-aligned:
`1. break — 15m` (white/dim) · `2. day 12 — 30m` (blue = upcoming/selected color scheme; odd rows white, even rows blue throughout) · `3. break — 15m` · `4. day 13 — 30m` · `5. break — 15m` · `6. day 14 — 30m` · `7. break — 15m` · `8. day 15 — 30m` · `9. break — 15m` · `10. day 16 — 30m` · `11. break — 15m` (last partially clipped). Thin separators between rows. Page dots unchanged.

### 5. IMG_6212.PNG — Interval-timer editor (board-level), top
1. **Nav bar**: ✕ circle button left; centered title **"Interval timer"**; right pill button **"Done"** (blue filled).
2. **Color row card**: 7 preset swatch circles (white, lime green, green, blue [selected — shows ring + dot center], dark blue, purple, magenta) + at far right a multicolor **custom-color picker swatch** (rainbow ball with brush icon).
3. **Icon/label row**: left small gray two-line text **"NO ICON"**, right = rounded text field with placeholder **"Add label"**.
4. **Toggle card**: **"Pause between intervals"** (blue title) + subtitle *"The timer will pause after each interval"*, toggle **ON** (green). Divider. **"Autocompletion"** + subtitle *"The timer will be automatically reset when finished."*, toggle **OFF**.
5. Section header **"Intervals"**, then a **toolbar bar** with 6 icon buttons: + (add), layers icon (group), layered-with-slash icon (ungroup, disabled), copy/pages icon (duplicate), trash (delete), ↑↓ (reorder). Non-+ icons are dimmed (nothing selected).
6. **Interval chips area**: left circle (selection radio) + a tall rounded bracket containing **`8`** (group repeat count) wrapping two chips stacked:
   - **`break`** (purple border, selected) with subtitle speaker icon + "illegal", right-aligned **`7m 30s`**
   - **`Cards`** (blue border) with subtitle "illegal", right **`15m`**
7. **Extra info card**: title **"Extra info"**, subtitle *"Select additional information displayed on the timer"*, and a picker value **"Overall time ⌃⌄"** (up/down chevrons).

### 6. IMG_6222.PNG — Per-interval editor ("Interval")
1. **Nav bar**: ‹ back circle button; centered title **"Interval"**. (No Done — edits are live.)
2. **Color card**: 7 swatches (green, blue, dark blue, purple [selected, ring+dot], magenta, pink/red, black) + rainbow custom swatch.
3. Label field containing value **"break"** (magenta text = interval's color).
4. **Duration card**: display bar showing **`7m 30s`**, then a 4-column keypad: rows `7 8 9 Days` / `4 5 6 Hours` / `1 2 3 Minutes` / `±  0  ⌫(backspace)  Seconds` — i.e. digits enter, right column assigns the unit to the entered number.
5. **Property card, 4 rows with separators**: **"Start Alert"** → value **"No alerting" ›**; **"End Alert"** → value **"illegal" ›** (speaker-based alert state); **"Repeat"** → value **`1`** (no chevron — opens in-place stepper popover, see #8); **"Note"** ›.

### 7. "Screenshot 2026-10-27 at 8.51.21 PM.png" — Color editor (pushed "Color" screen)
Structure top to bottom (no preset-swatches grid):
1. **Nav bar**: ‹ back circle; centered title **"Color"**.
2. **Preview card**: left = large solid swatch circle (current color, magenta); right = miniature timer dial preview (tick ring + readout **`06ᴴ:45ᴹ₀₀`**) ringed in the chosen color.
3. **2-D saturation/brightness gradient panel** (large rounded rect): hue varies left→right (red→yellow→green→cyan→blue→magenta→red), brightness top (white) → bottom (black).
4. **Brightness slider**: full-width pill, white→black left to right (no thumb visible in capture).
5. **Saved-palette row**: left **+** button; then 6 saved swatch circles (white, lime, green, blue, dark blue, purple — last partially clipped, row scrollable); right **trash** button (blue). No hue-only slider; no hex field visible.

### 8. "Screenshot 2026-10-27 at 8.58.11 PM.png" — Repeat stepper popover (group)
Context: "Interval timer" editor sheet dimmed (nav bar ✕ / "Interval timer" / "Done" visible; toggles, "Intervals" toolbar, and chip list visible behind: chips `day 13 — 30m`, `break — 15m`, `break — 15m`, `day 14 — 30m`, each with "illegal" subtitle, each preceded by an empty selection circle). The group-bracket repeat count on the selected group is being edited. The popover, floating over the toolbar/chip area:
- One dark rounded card, first row: **`−`** left, centered value **`1`**, **`+`** right.
- Divider, then a full-width **`OK`** button.
Exact wording is just "− / 1 / + / OK" — no other labels. Semantics: the bracket count sits on the group and equals **1** for a plain pass-through group, and the interval editor's "Repeat" row also defaults to **1** — combined with board behavior (1 = one pass, chip "8" wrapping a 2-interval group in IMG_6212 produces the alternating break/Cards schedule), **N = total number of passes, not extra repeats** (repeat=1 means play once). I flag this as consistent-but-inferred: no screenshot shows a >1 count with its resulting schedule, so the "extra repeats" reading can't be 100% excluded from images alone.

### 9. IMG_6229.PNG — Editor with one group
"Interval timer" sheet (✕ / title / Done). **"Intervals"** header + 6-icon toolbar. Chip list, top to bottom:
1. `Run — 50m` (blue border), subtitle "illegal", selection circle left.
2. **Group**: one selection circle, then a tall rounded bracket containing **`1`**, wrapping 4 chips: `Study (Anki) — 1h` (green border), `Jobs — 3h` (lime border), `Study (Labs) — 2h` (green), `Study — 3h` (blue). Each chip has "illegal" subtitle. Thin separators between the group's top and bottom and the surrounding items.
3. `get ready for bed — 10m` (blue).
4. `movie — 1h 10m` (purple/magenta border).
5. `read (tech) — 20m` (purple).
6. `read (fiction) — 20m` (dark purple).
Below: **"Extra info"** card header + subtitle "Select additional information displayed on the timer". Nesting is shown purely by the left bracket column: chips inside a group are indented right of the bracket; ungrouped chips align with the bracket itself.

### 10. IMG_6230.PNG — Editor with nested group
Same screen one minute later. The 4 study chips plus `get ready for bed — 10m` are now inside **two nested brackets**: outer bracket labeled **`1`** (with its own selection circle at far left) spanning all 5 chips, and an inner bracket labeled **`1`** spanning only the 4 study chips; `get ready for bed` sits inside the outer but outside the inner, indented accordingly. Run / movie / read (tech) / read (fiction) remain ungrouped as in #9. So: nesting = stacked left bracket columns, each carrying its own repeat number; deeper groups sit further right.

### 11. "Screenshot 2026-10-27 at 10.24.32 PM.png" — Alert selector ("Alert" screen)
1. **Nav bar**: left pill button **"‹ Back"** (chevron + "Back", blue); centered title **"Alert"**; right circular-outline button with **▶ (play) icon** = preview/alert test.
2. **Row card**: **"Sound"** → right value **"illegal ›"** (opens sound picker; value shown is the app's placeholder/unsupported state).
3. Caption under it, gray: *"Custom notification sounds are not supported on Apple Watch; the notification sound will always be the default one!"*
4. **Row card**: **"Warning"** + subtitle *"Makes 3 final beeping sounds"*, toggle **ON** (white knob, right).
Nothing else on the screen (no Vibration or Repeat rows in this variant — index.md's IMG_6223 lists those for the other alert-editor capture; this one shows only Sound + Warning).

---

### Key spec takeaways
- **Board dial, running/paused**: top small line = **total board time remaining** (not planned, not elapsed); big middle line = current interval time remaining (mm:ss), with `| PAUSED` appended when paused; divider; bottom line = `N. label` of current interval; below dial = `≫ next N. label - duration`.
- **Repeat semantics**: stepper is bare "− N + / OK"; default 1 everywhere → N is most consistent with **total passes** (Needs judgment: confirm against app behavior, images alone can't fully distinguish from "extra repeats").
- **Color editor**: preview (swatch + mini dial) → 2-D hue×brightness gradient → white-black brightness slider → scrollable saved-palette row with + and trash. No preset grid on this screen (the preset swatch row lives on the editors).
- **Group display**: left rounded bracket column with repeat number, chips indented inside; selection circles always at far left; nesting = additional bracket columns.

Sources: local files under `multitimer-spec/REFERENCE-IMAGES/` — IMG_6212.PNG, IMG_6214.PNG, IMG_6222.PNG, IMG_6229.PNG, IMG_6230.PNG, "Screenshot 2026-10-27 at 8.08.13 PM.png", "…8.09.21 PM.png", "…8.13.54 PM.png", "…8.51.21 PM.png", "…8.58.11 PM.png", "…10.24.32 PM.png", and index.md.

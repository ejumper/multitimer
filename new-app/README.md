# Planner v1 — monorepo

**Planner** (working title) is a single-board interval-timer app for Linux
desktop. Built with Flutter/Dart: a pure-Dart engine plus a thin Flutter app
that renders engine state and forwards user intents. See `../v1/PLAN/` for the
build plan, `../v1/OUTLINE.md` for locked decisions.

## Layout

```
new-app/
  packages/planner_engine/   # PURE Dart: data model, state machine, persistence interfaces.
                             # No flutter imports, no dart:io, no DateTime.now() — enforced by a test.
  apps/planner/              # Flutter Linux app: UI + OS adapters (clock, storage, notify, sound).
  scripts/                   # convenience wrappers (test.sh, build.sh)
```

The app depends on the engine via a path dependency
(`apps/planner/pubspec.yaml` → `../../packages/planner_engine`).

## v2 — the day planner

v2 (`v2/PLAN/` build plan, `v2/v2-outline.md` outline) turns the v1
interval timer into a day planner; v1's plan and docs stay under `v1/`.
Same app shell — a board screen plus a per-page pill-shaped bottom bar:

- **List view**: the dial is gone — the board renders the plan as
  editor-style rows (live `<left>/<total>` slots, left→right fills, group
  repeat countdowns), the current row rides near the center, and a
  right-click on a row jumps the run to it.
- **Completion**: every item carries a checkmark (Enter = ✓ at holds, one
  "not completed" button, Reset clears the marks). All-Open plans act as
  **checklists**: checked rows sink into a `Completed` section after a
  3-second un-check window, with show/hide on the bar and a
  checklist/chain mode toggle.
- **Library**: the folder-organized home of plans (routines, task lists,
  templates) — create/rename/delete/drag-reorder lists and folders, its
  own bar (home · new list · delete list), and save-to-folder via
  right-click on the board's Library button.
- **Calendar & days**: a week/month list of days with their interval
  counts (today highlighted), a popup date-setter, hover-revealed edge
  chevrons; tapping a day opens that day's board, and days lazy-fork
  their plan on the first write (reads never fork).
- **New Events**: quick capture of a dated interval into a day's plan
  (Save / Save & edit timer), overlapping times refused, past-due events
  saved and flagged late.
- **Settings**: New events override default timer, Home (current day vs a
  specific plan), Interval Options defaults, Calendar default view, and
  the Bottom Bar section — each setting feeds its consumer.
- **Bottom bars & quick actions**: every page renders its own bar; on the
  main bar, right-click Calendar opens the **non-default view** and
  right-click Library saves the open timer to a folder (Settings and New
  Event have no quick action). The plan board's bar carries home · back ·
  new item · delete mode · checklist · show/hide completed · defaults.

## Toolchain

- Flutter SDK via snap (`sudo snap install flutter --classic`), which also
  provides `dart` on PATH.
- Linux desktop deps: `sudo apt install clang libgtk-3-dev ninja-build`
  (plus cmake, pkg-config).
- `flutter doctor` should show **Linux toolchain ✓** (Android/Chrome warnings
  are irrelevant to v1).

## Build / run / test

From this directory (`new-app/`):

```sh
scripts/test.sh        # dart test (engine) + flutter test (app)
scripts/build.sh       # flutter build linux --release
```

Directly, per package:

```sh
cd packages/planner_engine && dart test
cd apps/planner && flutter test
cd apps/planner && flutter build linux --release
build/linux/x64/release/bundle/planner   # run the built app
cd apps/planner && flutter run -d linux  # dev run with hot reload
```

## Smoke checks

```sh
PLANNER_SMOKE=1    ./apps/planner/build/linux/x64/release/bundle/planner  # one KDE notification
PLANNER_SMOKE=alert ./apps/planner/build/linux/x64/release/bundle/planner  # full alert pipeline
```
Both print `SMOKE_OK` and exit; the alert smoke drives a real 1-second session
through the engine into the real notifier + sound player (in-memory DB — the
real change log stays clean).

## Install (KDE/Linux)

```sh
scripts/build.sh        # release bundle
scripts/install.sh      # -> ~/.local (app, icon, launcher) — no root
```

`install.sh` copies the self-contained bundle to `~/.local/lib/planner`,
installs the icon (`assets/icon/planner-timer.png`) into the hicolor theme
writes `~/.local/share/applications/com.example.planner.desktop` (named after the app-id so Wayland resolves the decoration icon), and symlinks
`~/.local/bin/planner` for terminal use. Then "Planner" appears in the
app launcher. Re-run after a rebuild to upgrade; `scripts/uninstall.sh`
removes all of it.

## Desktop notes

- The window background is **fully transparent** — your compositor (KWin)
  supplies the blur. Recipe lives in
  `apps/planner/linux/runner/my_application.cc` (RGBA visual + app-paintable +
  transparent `FlView` background; see flutter/flutter#152154). Server-side KDE
  decorations come from NOT setting a GTK header bar (xdg-decoration). Second
  launches focus the existing window (GApplication single-instance).
- Fonts (`assets/fonts/`) are **local-only, gitignored** — copy from
  `/usr/local/share/fonts/` (`p/ProLisa_Regular.ttf`, `p/ProLisa_Bold.ttf`,
  `m/MonoLisa_Medium.ttf`, `m/MonoLisa_Black.ttf`); a fresh clone needs
  them before `flutter run`. The tray icon (`assets/tray/`) is the app
  icon and **is committed** (see `assets/icon/`).
- Close button (Alt+F4, task-manager close): **hides to tray while a run
  is active** — alerts keep firing — and **quits when idle** (the hybrid
  close policy). Restore via the tray menu's **Show Planner**; **Quit**
  exits unconditionally.
- v1 plan + reports + acceptance script live in `v1/` (`v1/ACCEPTANCE.md`,
  `v1/BUILD-NOTES.md`).

There is no top-level pubspec/workspace on purpose: each package resolves on
its own and the scripts above are the single entry point.

## Engine codegen (drift)

`packages/planner_engine` generates `lib/storage/planner_db.g.dart` via drift:

```sh
cd packages/planner_engine && dart run build_runner build --delete-conflicting-outputs
```

NB (toolchain quirks found in P1.1, drift_dev 2.35.2 / Dart 3.13.7):

- `int32()` and `textEnum<>()` column types **silently break code generation**
  (empty `.g.dart`, no error). Use `integer()` (same 64-bit SQLite type) and
  map enums by name in `DriftStore` instead.
- If generation ever emits a suspiciously tiny `.g.dart`, delete it and
  `.dart_tool/build/`, then rebuild.

## Conventions that matter here

- `packages/planner_engine` must stay **pure Dart** — a purity test in the
  engine fails the suite if `lib/` ever imports `dart:io` or Flutter.
- Fonts (`apps/planner/assets/fonts/`) and sounds (`assets/sounds/`) are
  **local-only, gitignored** assets — licensed/user-supplied files, never
  committed (repo is public).

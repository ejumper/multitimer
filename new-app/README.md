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

## Desktop prototype notes (P0.2)

- The window background is **fully transparent** — your compositor (KWin)
  supplies the blur. Recipe lives in
  `apps/planner/linux/runner/my_application.cc` (RGBA visual + app-paintable +
  transparent `FlView` background; see flutter/flutter#152154).
- Fonts (`assets/fonts/`) and the tray icon (`assets/tray/`) are **local-only,
  gitignored**. Regenerate the tray icon with
  `python3 scripts/gen_tray_icon.py`; copy fonts from `/usr/local/share/fonts/`
  (`p/ProLisa_Regular.ttf`, `p/ProLisa_Bold.ttf`, `m/MonoLisa_Medium.ttf`,
  `m/MonoLisa_Black.ttf`) — a fresh clone needs both before `flutter run`.
- Close button hides to tray; restore via the tray menu's **Show Planner**
  (on KDE, clicking the tray icon opens its menu); **Quit** exits.

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

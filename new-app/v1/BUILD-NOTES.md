# Planner v1 — Build Notes (for the next phase)

Written at the end of the v1 build (2026-10-28). What follows is the honest map:
what's solid, what's rough, where the seams are, and a suggested order for what
comes next. Decisions of record: `../v1/OUTLINE.md`; acceptance: `ACCEPTANCE.md`.

## The shape of the thing

```
new-app/
  packages/planner_engine/   # pure Dart: model, tree ops, flatten, TimerSession,
                             # event/alert decisions, drift store (injected DB)
  apps/planner/              # Flutter Linux: UI + adapters (clock/store/notify/sound)
  v1/                        # plan + reports + this file
```

The engine is the product (CONVENTIONS: "the architecture is the product"). It is
fully deterministic: `Clock` + `Store` + `EventSink` injected, 108 tests, a
purity test that bans flutter/dart:io outside `storage/impl/`. The app renders
`TimerSession.snapshot(now)` (pure projection) and forwards intents; a 1 Hz
heartbeat does `settle` → `flush` → rebuild.

## Solid ground (build on this freely)

- **TimerSession** (P1.3): wall-clock anchors, pure projection, exact
  zero-crossing semantics (`finish_armed_only_in_future`,
  `last_instant_pause_crossing_wins`, overshoot cascade / manual-absorb).
  Re-read `lib/timer_session.dart` docs before touching execution logic.
- **Tree ops** (P1.1): immutable `IntervalTree` with tested group/ungroup/
  duplicate/delete/move semantics. The editor mutates a working copy through
  the SAME ops — semantics can't drift between UI and engine.
- **Flatten** (P1.2): repeat N = total passes; snapshots def values.
- **Change log** (D4 groundwork): every store mutation appends an event
  (UNIQUE seq); run terminals land as `run.terminal` entries keyed to the true
  end moment. This is the sync foundation — treat it as append-only forever.

## Rough edges (honest list)

1. **Editor commit granularity**: a timer-editor Done writes ONE `editor.commit`
   event (whole tree), not per-action events. Fine locally; if sync ever lands,
   per-action replay or a tree diff is the upgrade path (P4.1 report).
2. **`build_runner`/drift codegen trap**: drift_dev 2.35.2 silently emits an
   EMPTY `.g.dart` when a schema uses `int32()` or `textEnum<>()` (Dart 3.13).
   We use `integer()` + name-based enum mapping. If drift fixes it, nothing
   needs to change, but don't "clean up" to `textEnum` without re-checking.
   Regen: `dart run build_runner build --delete-conflicting-outputs` (if the
   generated file is tiny, delete it + `.dart_tool/build` and rerun).
3. ~~Mock board is dead weight~~ — **removed in the final cleanup** (it was
   the P0.2 shell prototype; `board_screen.dart` superseded it).
4. **Single-instance is GApplication-id based** (`com.example.planner` — the
   TEMPLATE id). When app identity is decided (Android time, D10), rename the
   APPLICATION_ID in `linux/CMakeLists.txt` and the desktop file together.
5. **Widget tests construct controllers in-body and dispose before the test
   ends** (flutter_test checks pending-timer invariants before `addTearDown`).
   Keep that pattern for anything with a ticker.
6. **Notification actions** (the P6.1 stretch): only `Continue`, only on
   manually-complete alerts. The parked items (Snooze/Reset buttons, action on
   auto-finish alerts) live in `../FINAL-APP-OUTLINE.md` §Parked.
7. ~~No app icon / .desktop file~~ — **resolved**: the app icon
   (`assets/icon/planner-timer.png`) drives the launcher, taskbar, window
   decoration and tray; `scripts/install.sh` installs the bundle + a
   `com.example.planner.desktop` entry (the app-id name is what Wayland
   decoration lookup needs). Flatpak/deb packaging remains v2.
8. **Test-only `drift` dependency in the app** also serves `PLANNER_SMOKE=alert`
   (in-memory DB so smoke runs don't pollute the real change log).

## Suggested v2 order (opinionated)

1. **Editor polish**: per-action undo across the interval editor (it's buffered
   today), drag-reorder refinement (drop indicators), real icon set for chips.
2. **Run history UI**: the change log already records every terminal
   (`run.terminal`); a read-only history view is pure presentation work.
3. **Start alerts + pre-warnings** (engine already emits instance-end events;
   the start-of-instance event and lead-time scheduling are additive).
4. **Multi-board** (entities exist: Board 1:N Timer; UI: the hamburger menu and
   page dots from the reference).
5. **Dated triggers** (`TriggerMethod.date` stored since P1.1 — the "walls" of
   FINAL-APP-OUTLINE §2.2 are the big engine feature).
6. **Sync** (D4): the append-only log is the substrate; Nextcloud file-sync is
   the candidate — design it properly, it's the north star's hardest part.
7. **Android** (package-id decision lands here; AlarmManager/foreground-service
   per the MultiTimer SPEC `../multitimer-spec/SPEC/engine.md` §5).

## Toolchain facts (don't rediscover)

- Flutter 3.47.8 (snap) + Dart 3.13.7; Kubuntu/Wayland/KWin.
- `libayatana-appindicator3-dev` is a build dep (system_tray); `libgstreamer1.0-dev
  + libgstreamer-plugins-base1.0-dev` for audioplayers.
- tray_manager 0.8/nativeapi **silently fails** SNI registration on this box —
  system_tray works. Avoid nativeapi-based packages until that's sorted.
- Wayland + KDE: never set a GTK header bar if you want the user's window
  theme (SSD via xdg-decoration is the working recipe in `my_application.cc`).
- Screenshots are portal-gated on Plasma 6 (approval dialog) — automated visual
  regression is not available; widget tests assert structure/text instead.
- `sudo apt-get update` fails on the `home:justkidding` repo (NO_PUBKEY) —
  `apt-get install` directly works fine.

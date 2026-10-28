import 'dart:io';

import 'package:planner_engine/planner_engine.dart';

import 'system_clock.dart';

/// XDG data-dir helpers and the store factory (D10: the app owns path
/// resolution; the engine only opens what it is handed).
///
/// Layout: `$XDG_DATA_HOME/planner/` (default `~/.local/share/planner/`)
/// holding `planner.db` and the `sounds/` alert-sound directory.

/// The app's data directory: `$XDG_DATA_HOME/planner` if `XDG_DATA_HOME` is
/// set (and non-empty), else `~/.local/share/planner`.
String plannerDataDir() {
  final xdg = Platform.environment['XDG_DATA_HOME'];
  final base = (xdg == null || xdg.isEmpty)
      ? '${Platform.environment['HOME'] ?? ''}/.local/share'
      : xdg;
  return '$base/planner';
}

/// The alert-sounds directory (user drops mp3 files in here).
String plannerSoundsDir() => '${plannerDataDir()}/sounds';

/// Creates the data and sounds directories (idempotent).
Future<void> ensurePlannerDirs() async {
  await Directory(plannerDataDir()).create(recursive: true);
  await Directory(plannerSoundsDir()).create(recursive: true);
}

/// Opens (creating it and its parent directories on first use) the drift
/// store on the SQLite file at [dbPathOverride] or the default
/// `<data dir>/planner.db`.
Future<Store> openPlannerStore({String? dbPathOverride}) async {
  final path = dbPathOverride ?? '${plannerDataDir()}/planner.db';
  return DriftStore(PlannerDb(openSqliteFile(path)), SystemClock());
}

/// File names (not paths) of the `*.mp3` files in [plannerSoundsDir],
/// sorted alphabetically. Rescans on every call (rescan-on-demand API);
/// returns an empty list when the directory does not exist.
List<String> listSoundFiles() {
  final dir = Directory(plannerSoundsDir());
  if (!dir.existsSync()) return <String>[];
  final names = <String>[
    for (final entity in dir.listSync(followLinks: false))
      if (entity is File && entity.path.endsWith('.mp3'))
        entity.path.split('/').last,
  ]..sort();
  return names;
}

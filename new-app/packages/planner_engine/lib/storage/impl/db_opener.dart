/// The engine's single `dart:io` exception (CONVENTIONS §2): opening the
/// SQLite file. Everything above this line is pure Dart; the app injects the
/// XDG data-dir path (D10: `~/.local/share/planner/`), the engine never
/// resolves it.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Opens (and creates, incl. parent directories) the SQLite database file at
/// [path]. Runs queries on a background isolate.
LazyDatabase openSqliteFile(String path) => LazyDatabase(() async {
  final file = File(path);
  await file.parent.create(recursive: true);
  return NativeDatabase.createInBackground(file);
});

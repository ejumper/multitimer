/// Drift schema mirroring the domain entities (P1.1, D4).
///
/// Tables encode the tree as rows: `parentGroupId` + `sortIndex`/`orderIndex`
/// columns are derived from [IntervalTree] positions on save and rebuilt into
/// tree structure on load. `schemaVersion` + drift migrations exist from day
/// one; v1 is version 1.
///
/// The database is opened via an injected `QueryExecutor` — the app supplies
/// the on-disk opener from `storage/impl/` (the engine's only `dart:io`).
library;

import 'package:drift/drift.dart';

part 'planner_db.g.dart';

@DataClassName('BoardRow')
class Boards extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TimerRow')
class Timers extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get name => text()();
  TextColumn get color => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('IntervalDefRow')
class IntervalDefs extends Table {
  TextColumn get id => text()();
  TextColumn get timerId => text()();
  TextColumn get name => text().nullable()();
  TextColumn get color => text()();
  IntColumn get durationSeconds => integer()();
  BoolColumn get autoFinish => boolean()();
  TextColumn get endAlertSoundFile => text().nullable()();
  TextColumn get parentGroupId => text().nullable()();
  IntColumn get sortIndex => integer()();

  // Groundwork fields (v1: stored, defaulted, inert). Stored as TEXT enum
  // names — NB: textEnum<>() (drift_dev 2.35.2, Dart 3.13) silently breaks
  // code generation, so enum mapping is done in DriftStore instead.
  TextColumn get completionDefault => text()();
  TextColumn get trigger => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GroupDefRow')
class GroupDefs extends Table {
  TextColumn get id => text()();
  TextColumn get timerId => text()();
  IntColumn get repeatCount => integer()();
  TextColumn get parentGroupId => text().nullable()();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only change log (D4). Rows are never updated or deleted. `seq` is
/// a monotonic insertion counter assigned by [DriftStore] (rowid ordering is
/// an SQLite implementation detail; this makes event order explicit).
@DataClassName('EventLogRow')
class EventLog extends Table {
  TextColumn get id => text()();
  // UNIQUE: event order is enforced by the schema, not by convention — a
  // duplicate seq must be impossible even if two writers ever race.
  IntColumn get seq => integer().unique()();
  IntColumn get timestampMs => integer()();
  TextColumn get kind => text()();
  TextColumn get payloadJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Boards, Timers, IntervalDefs, GroupDefs, EventLog])
class PlannerDb extends _$PlannerDb {
  PlannerDb(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // v1 has a single schema; upgrades add steps here from v2 on.
    onUpgrade: (m, from, to) async {
      for (var v = from + 1; v <= to; v++) {
        // Future migrations switch on v.
      }
    },
  );
}

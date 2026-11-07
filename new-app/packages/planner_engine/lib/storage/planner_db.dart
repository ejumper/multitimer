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
  // v2 (P1.1): nullable — null = Open (no duration).
  IntColumn get durationSeconds => integer().nullable()();
  BoolColumn get autoFinish => boolean()();
  TextColumn get endAlertSoundFile => text().nullable()();
  TextColumn get parentGroupId => text().nullable()();
  IntColumn get sortIndex => integer()();

  // v2 (P1.1): the completion mark (replaces the inert `completionDefault`
  // groundwork column, migrated in v2). Bool — no enum mapping needed.
  BoolColumn get completed => boolean()();

  // v2 (P1.1): the trigger method by presence — null = order-triggered,
  // non-null = date-triggered at this time-of-day (seconds since midnight,
  // local). Replaces the groundwork `trigger` column (migrated away; every
  // v1 row was `order`, so every migrated value is null).
  IntColumn get triggerTimeSeconds => integer().nullable()();

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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      for (var v = from + 1; v <= to; v++) {
        switch (v) {
          case 2:
            await _migrate1To2(m);
        }
      }
    },
  );

  /// v2 (P1.1): interval_defs gains nullable duration + the completion mark
  /// + the trigger time. SQLite cannot alter a column's nullability, so the
  /// table is recreated in the v2 shape and v1 rows are carried over:
  /// `completion_default` TEXT ('completed'/'notCompleted') → `completed`
  /// bool; the groundwork `trigger` column is dropped (all v1 rows are
  /// `order` ⇒ trigger_time_seconds stays null).
  Future<void> _migrate1To2(Migrator m) async {
    await customStatement(
      'ALTER TABLE interval_defs RENAME TO interval_defs_v1',
    );
    await m.createTable(intervalDefs);
    await customStatement(
      'INSERT INTO interval_defs '
      '(id, timer_id, name, color, duration_seconds, auto_finish, '
      'end_alert_sound_file, parent_group_id, sort_index, completed, '
      'trigger_time_seconds) '
      'SELECT id, timer_id, name, color, duration_seconds, auto_finish, '
      'end_alert_sound_file, parent_group_id, sort_index, '
      "CASE WHEN completion_default = 'completed' THEN 1 ELSE 0 END, NULL "
      'FROM interval_defs_v1',
    );
    await customStatement('DROP TABLE interval_defs_v1');
  }
}

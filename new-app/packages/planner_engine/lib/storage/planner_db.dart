/// Drift schema mirroring the domain entities (P1.1, D4).
///
/// Tables encode the tree as rows: `parentGroupId` + `sortIndex`/`orderIndex`
/// columns are derived from [IntervalTree] positions on save and rebuilt into
/// tree structure on load. `schemaVersion` + drift migrations exist from day
/// one: v1 = version 1, v2 (P1.1) = version 2, the Library (P3.2) =
/// version 3, default rules (P3.4) = version 4.
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

  // v2 (P3.2): the Library columns (schema v3). A timer IS a plan —
  // [folderId] places it in a folder (null = the library root),
  // [sortIndex] orders it within that folder (ascending; new plans land
  // on top), and [createdAt]/[updatedAt] are the row date's stamps
  // (epoch ms; `run.mark` writes do not bump [updatedAt] — marks are
  // execution, not authoring). Inserted by [DriftStore] from its injected
  // Clock; the v2→v3 migration backfills with SQLite's clock + rowid.
  TextColumn get folderId => text().nullable()();
  IntColumn get sortIndex => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Library folders (v2 P3.2): flat organization over the board's plans;
/// `sortIndex` orders the folders themselves (ascending, creation order).
@DataClassName('FolderRow')
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortIndex => integer()();

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

/// Default rules (v2 P3.4): a library plan's claims on calendar days.
/// `kind` is the [DefaultRuleKind] wire TEXT ('default'/'weekday'/
/// 'monthday'/'date') — mapped by NAME in [DriftStore] (drift's textEnum
/// breaks codegen, BLOCKERS #2). `value` is null for a global default,
/// 1–7 (Monday=1) / 1–31 for a REPEATING weekday/monthday rule, and the
/// local day as YYYYMMDD for a `date` rule AND for any one-off
/// (repeat = false) weekday/monthday rule — "default for this Tuesday"
/// without repeat means exactly that date. See [DefaultRule].
@DataClassName('DefaultRuleRow')
class DefaultRules extends Table {
  TextColumn get id => text()();
  TextColumn get timerId => text()();
  TextColumn get kind => text()();
  IntColumn get value => integer().nullable()();
  BoolColumn get repeat => boolean()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Boards,
    Timers,
    IntervalDefs,
    GroupDefs,
    EventLog,
    Folders,
    DefaultRules,
  ],
)
class PlannerDb extends _$PlannerDb {
  PlannerDb(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      for (var v = from + 1; v <= to; v++) {
        switch (v) {
          case 2:
            await _migrate1To2(m);
          case 3:
            await _migrate2To3(m);
          case 4:
            await _migrate3To4(m);
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

  /// v2 (P3.2): the Library — `folders` plus the Timers library columns
  /// (folder placement/order + created/modified stamps). SQLite cannot add
  /// a NOT NULL column without a default, so each lands with `DEFAULT 0`
  /// and is backfilled: sort order from `rowid` (creation order — every v2
  /// row was created in insertion order), timestamps from SQLite's clock
  /// (`strftime`): the ENGINE has no Dart clock (CONVENTIONS §2), and
  /// migration-time is the honest stamp for rows whose true origin is not
  /// stored. [DriftStore] keeps writing both from its injected Clock from
  /// then on.
  ///
  /// Every step is presence-guarded: a test-fabricated "old" database is
  /// carved out of a current-schema file (its newer tables/columns already
  /// exist next to `user_version`), and that shape must migrate cleanly
  /// too — genuine v1/v2 databases run the full path.
  Future<void> _migrate2To3(Migrator m) async {
    final foldersExists = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'folders'",
    ).get();
    if (foldersExists.isEmpty) {
      await m.createTable(folders);
    }

    final columns = {
      for (final row in await customSelect('PRAGMA table_info(timers)').get())
        row.read<String>('name'),
    };
    Future<void> addColumn(String name, String ddl) async {
      if (!columns.contains(name)) await customStatement(ddl);
    }

    await addColumn(
      'folder_id',
      'ALTER TABLE timers ADD COLUMN folder_id TEXT',
    );
    await addColumn(
      'sort_index',
      'ALTER TABLE timers ADD COLUMN sort_index INTEGER NOT NULL DEFAULT 0',
    );
    await addColumn(
      'created_at',
      'ALTER TABLE timers ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
    );
    await addColumn(
      'updated_at',
      'ALTER TABLE timers ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
    );

    // Creation order for rows that never had an explicit position; the
    // stamps only fill rows the columns just landed on (value 0).
    await customStatement('UPDATE timers SET sort_index = rowid');
    await customStatement(
      'UPDATE timers '
      "SET created_at = CAST(strftime('%s','now') AS INTEGER) * 1000, "
      "updated_at = CAST(strftime('%s','now') AS INTEGER) * 1000 "
      'WHERE created_at = 0',
    );
  }

  /// v4 (P3.4): the `default_rules` table (schema v4). Purely additive —
  /// presence-guarded like v2→v3, so a test-fabricated "old" database
  /// carved out of a current-schema file (whose table already exists
  /// beside `user_version`) migrates cleanly too.
  Future<void> _migrate3To4(Migrator m) async {
    final rulesExist = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'default_rules'",
    ).get();
    if (rulesExist.isEmpty) {
      await m.createTable(defaultRules);
    }
  }
}

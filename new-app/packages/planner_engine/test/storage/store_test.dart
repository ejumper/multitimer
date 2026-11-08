import 'dart:io';

import 'package:drift/native.dart';
import 'package:planner_engine/planner_engine.dart';
import 'package:test/test.dart';

/// Storage contract tests (P1.1): round-trip, CRUD, change log. Uses an
/// in-memory SQLite; the v2-migration test alone needs a real file (close /
/// reopen across versions), hence dart:io here.
void main() {
  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;

  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 10, 28, 12));
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);
  });

  tearDown(() => store.close());

  IntervalTree demoTree(String timerId) => IntervalTree([
    DefNode(
      IntervalDef(
        id: 'a',
        timerId: timerId,
        name: 'break',
        color: '#ff00b1',
        durationSeconds: 450,
        autoFinish: false,
        endAlertSoundFile: 'ding.mp3',
      ),
    ),
    GroupNode(GroupDef(id: 'g1', timerId: timerId, repeatCount: 8), [
      DefNode(
        IntervalDef(
          id: 'b',
          timerId: timerId,
          color: '#4800ff',
          durationSeconds: 900,
          autoFinish: true,
        ),
      ),
      GroupNode(GroupDef(id: 'g2', timerId: timerId, repeatCount: 1), [
        DefNode(
          IntervalDef(
            id: 'c',
            timerId: timerId,
            color: '#00ad6b',
            durationSeconds: 3600,
            autoFinish: true,
          ),
        ),
      ]),
    ]),
    DefNode(
      IntervalDef(
        id: 'd',
        timerId: timerId,
        color: '#0055ff',
        durationSeconds: 60,
        autoFinish: true,
      ),
    ),
  ]);

  group('board + timer CRUD', () {
    test('create/find/rename/delete board', () async {
      final b = await store.createBoard('tmp');
      expect((await store.allBoards()).single.id, b.id);

      await store.renameBoard(b.id, 'renamed');
      expect((await store.allBoards()).single.name, 'renamed');

      final t = await store.createTimer(
        boardId: b.id,
        name: 'day chain',
        color: '#0055ff',
      );
      expect((await store.timersInBoard(b.id)).single.id, t.id);

      await store.deleteBoard(b.id);
      expect(await store.allBoards(), isEmpty);
      expect(await store.timersInBoard(b.id), isEmpty);
    });

    test('updateTimer changes name/color', () async {
      final b = await store.createBoard('b');
      final t = await store.createTimer(
        boardId: b.id,
        name: 'x',
        color: '#0055ff',
      );
      await store.updateTimer(t.id, name: 'y', color: '#ff00b1');
      final loaded = (await store.timersInBoard(b.id)).single;
      expect(loaded.name, 'y');
      expect(loaded.color, '#ff00b1');
    });
  });

  group('round-trip', () {
    test('persist → load reproduces the identical nested tree', () async {
      final b = await store.createBoard('tmp');
      final t = await store.createTimer(
        boardId: b.id,
        name: 'chain',
        color: '#0055ff',
      );

      final original = demoTree(t.id);
      await store.saveTree(t.id, original, eventKind: 'tree.save');
      final loaded = await store.loadTree(t.id);

      expect(loaded.toDebugString(), original.toDebugString());
      expect(loaded.allIds, original.allIds);

      // Field-level: the deepest interval keeps every property.
      final node = loaded.nodeById('a') as DefNode;
      expect(node.def.name, 'break');
      expect(node.def.color, '#ff00b1');
      expect(node.def.durationSeconds, 450);
      expect(node.def.autoFinish, isFalse);
      expect(node.def.endAlertSoundFile, 'ding.mp3');
      // v2 fields round-trip: mark and trigger-time default sanely.
      expect(node.def.completed, isFalse);
      expect(node.def.triggerTimeSeconds, isNull);

      // Group repeat counts survive at both depths.
      expect((loaded.nodeById('g1') as GroupNode).group.repeatCount, 8);
      expect((loaded.nodeById('g2') as GroupNode).group.repeatCount, 1);
    });

    test('tree ops through the store persist and stay consistent', () async {
      final b = await store.createBoard('tmp');
      final t = await store.createTimer(
        boardId: b.id,
        name: 'chain',
        color: '#0055ff',
      );
      await store.saveTree(t.id, demoTree(t.id), eventKind: 'tree.save');

      final grouped = await store.groupNodes(
        timerId: t.id,
        nodeIds: ['a', 'd'],
        repeatCount: 2,
      );
      final reloaded = await store.loadTree(t.id);
      expect(grouped.toDebugString(), reloaded.toDebugString());
      expect(
        reloaded.parentOf('a'),
        isNotNull,
        reason: 'a and d now share a new group',
      );

      final moved = await store.moveNode(
        timerId: t.id,
        nodeId: 'b',
        newParentGroupId: null,
        newIndex: 0,
      );
      expect(
        (await store.loadTree(t.id)).toDebugString(),
        moved.toDebugString(),
      );
    });

    test('v2 fields round-trip non-default values', () async {
      // marks and wall times are load-bearing in v2 — they must survive
      // storage exactly.
      final b = await store.createBoard('tmp');
      final t = await store.createTimer(
        boardId: b.id,
        name: 'chain',
        color: '#0055ff',
      );
      final tree = IntervalTree([
        DefNode(
          IntervalDef(
            id: 'a',
            timerId: t.id,
            color: '#0055ff',
            durationSeconds: 10,
            autoFinish: true,
            completed: true,
            triggerTimeSeconds: 14 * 3600,
          ),
        ),
      ]);
      await store.saveTree(t.id, tree, eventKind: 'tree.save');
      final node = (await store.loadTree(t.id)).nodeById('a') as DefNode;
      expect(node.def.completed, isTrue);
      expect(node.def.triggerTimeSeconds, 14 * 3600);
      expect(node.def.durationSeconds, 10);
    });

    test('Open intervals round-trip a null duration', () async {
      final b = await store.createBoard('tmp');
      final t = await store.createTimer(
        boardId: b.id,
        name: 'chain',
        color: '#0055ff',
      );
      final tree = IntervalTree([
        DefNode(
          IntervalDef(
            id: 'a',
            timerId: t.id,
            color: '#0055ff',
            durationSeconds: null,
            autoFinish: false,
          ),
        ),
      ]);
      await store.saveTree(t.id, tree, eventKind: 'tree.save');
      final node = (await store.loadTree(t.id)).nodeById('a') as DefNode;
      expect(node.def.durationSeconds, isNull);
      expect(node.def.isOpen, isTrue);
    });
  });

  group('schema v2 migration (P1.1)', () {
    test(
      'v1 rows carry over: mark from completion_default, trigger dropped',
      () async {
        final dir = Directory.systemTemp.createTempSync('planner_migration');
        final file = File('${dir.path}/mig.db');

        // Phase 1: a schemaVersion-1 database with one interval whose mark is
        // stored the v1 way (completion_default TEXT).
        final v1 = PlannerDb(NativeDatabase(file));
        await v1.customStatement('DROP TABLE interval_defs');
        await v1.customStatement(
          'CREATE TABLE interval_defs ('
          'id TEXT NOT NULL, timer_id TEXT NOT NULL, name TEXT NULL, '
          'color TEXT NOT NULL, duration_seconds INTEGER NOT NULL, '
          'auto_finish INTEGER NOT NULL, end_alert_sound_file TEXT NULL, '
          'parent_group_id TEXT NULL, sort_index INTEGER NOT NULL, '
          'completion_default TEXT NOT NULL, trigger TEXT NOT NULL, '
          'PRIMARY KEY (id))',
        );
        await v1.customStatement(
          "INSERT INTO interval_defs VALUES ('a', 'tim', 'break', '#ff00b1', "
          "450, 0, 'ding.mp3', NULL, 0, 'completed', 'order')",
        );
        await v1.customStatement('PRAGMA user_version = 1');
        await v1.close();

        // Phase 2: reopening under the v2 schema runs the 1→2 migration.
        final v2 = PlannerDb(NativeDatabase(file));
        final rows = await v2.select(v2.intervalDefs).get();
        expect(rows, hasLength(1));
        expect(rows.single.id, 'a');
        expect(rows.single.completed, isTrue); // 'completed' TEXT → true
        expect(rows.single.durationSeconds, 450);
        expect(rows.single.triggerTimeSeconds, isNull); // v1 was always order
        await v2.close();

        dir.deleteSync(recursive: true);
      },
    );
  });

  group('library folders (P3.2)', () {
    test(
      'folder create/rename/delete: cascade drops folder plans only',
      () async {
        final b = await store.createBoard('b');
        expect(await store.allFolders(), isEmpty);

        final f = await store.createFolder('Errands');
        final inFolder = await store.createTimer(
          boardId: b.id,
          name: 'Chores',
          color: '#0055ff',
          folderId: f.id,
        );
        final atRoot = await store.createTimer(
          boardId: b.id,
          name: 'Weekend',
          color: '#0055ff',
        );

        await store.renameFolder(f.id, 'Errands+');
        expect((await store.allFolders()).single.name, 'Errands+');
        await expectLater(
          store.renameFolder('missing', 'x'),
          throwsA(isA<StateError>()),
        );

        await store.deleteFolder(f.id);
        expect(await store.allFolders(), isEmpty);
        // The folder's plans go with it; folder-less root plans survive.
        final remaining = await store.timersInBoard(b.id);
        expect(remaining.map((t) => t.id), [atRoot.id]);
        expect(remaining.single.id, isNot(inFolder.id));

        // The change log tells the whole story in order.
        final kinds = [for (final e in await store.events()) e.kind];
        expect(
          kinds,
          containsAllInOrder(<String>[
            'folder.create',
            'folder.rename',
            'timer.delete',
            'folder.delete',
          ]),
        );
      },
    );

    test(
      'new plans land on top; moveTimer reorders within/between folders',
      () async {
        final b = await store.createBoard('b');
        final f = await store.createFolder('Errands');
        final g = await store.createFolder('Routines');
        final t1 = await store.createTimer(
          boardId: b.id,
          name: 'one',
          color: '#0055ff',
          folderId: f.id,
        );
        await store.createTimer(
          boardId: b.id,
          name: 'two',
          color: '#0055ff',
          folderId: f.id,
        );
        final t3 = await store.createTimer(
          boardId: b.id,
          name: 'three',
          color: '#0055ff',
          folderId: f.id,
        );
        await store.createTimer(boardId: b.id, name: 'root', color: '#0055ff');

        Future<List<String>> order(String? folderId) async {
          final children =
              (await store.timersInBoard(b.id))
                  .where((t) => t.folderId == folderId)
                  .toList()
                ..sort((a, c) => a.sortIndex.compareTo(c.sortIndex));
          return [for (final t in children) t.name];
        }

        // createTimer lands on TOP (ascending sort index below the minimum).
        expect(await order(f.id), ['three', 'two', 'one']);
        expect(await order(null), ['root']);

        // Within the folder: 'three' moves to the bottom (index 2 of 3).
        await store.moveTimer(timerId: t3.id, toFolderId: f.id, toIndex: 2);
        expect(await order(f.id), ['two', 'one', 'three']);

        // Between folders: 'one' moves to the root, on top.
        await store.moveTimer(timerId: t1.id, toFolderId: null, toIndex: 0);
        expect(await order(f.id), ['two', 'three']);
        expect(await order(null), ['one', 'root']);

        // Into an empty folder (index clamped into range), densely renumbered.
        await store.moveTimer(timerId: t3.id, toFolderId: g.id, toIndex: 5);
        expect(await order(f.id), ['two']);
        expect(await order(g.id), ['three']);
        final moved = (await store.timersInBoard(b.id))
            .firstWhere((t) => t.id == t3.id);
        expect(moved.sortIndex, 0);
        expect(moved.folderId, g.id);

        await expectLater(
          store.moveTimer(timerId: 'missing', toFolderId: null, toIndex: 0),
          throwsA(isA<StateError>()),
        );
        expect((await store.events()).last.kind, 'timer.move');
      },
    );

    test(
      'created/updatedAt stamps: rename + tree edits bump, run marks do not',
      () async {
        final ownClock = MutableClock(DateTime.utc(2026, 11, 7, 9));
        final ownStore = DriftStore(
          PlannerDb(NativeDatabase.memory()),
          ownClock,
        );
        addTearDown(ownStore.close);

        final b = await ownStore.createBoard('b');
        final t = await ownStore.createTimer(
          boardId: b.id,
          name: 'x',
          color: '#0055ff',
        );
        expect(t.createdAt, ownClock.now().millisecondsSinceEpoch);
        expect(t.updatedAt, t.createdAt);

        // A rename bumps only the modified stamp.
        ownClock.current = ownClock.current.add(const Duration(hours: 1));
        await ownStore.updateTimer(t.id, name: 'y');
        var loaded = (await ownStore.timersInBoard(b.id)).single;
        expect(loaded.name, 'y');
        expect(loaded.createdAt, t.createdAt);
        expect(loaded.updatedAt, ownClock.now().millisecondsSinceEpoch);

        // An authored tree write bumps it too.
        final tree = IntervalTree([
          DefNode(
            IntervalDef(
              id: 'a',
              timerId: t.id,
              color: '#0055ff',
              durationSeconds: 10,
              autoFinish: true,
            ),
          ),
        ]);
        ownClock.current = ownClock.current.add(const Duration(hours: 1));
        await ownStore.saveTree(t.id, tree, eventKind: 'tree.save');
        loaded = (await ownStore.timersInBoard(b.id)).single;
        expect(loaded.updatedAt, ownClock.now().millisecondsSinceEpoch);

        // Completion marks are execution, not authoring — the stamp stands.
        ownClock.current = ownClock.current.add(const Duration(hours: 1));
        await ownStore.saveTree(
          t.id,
          tree.updated('a', (d) => d.copyWith(completed: true)),
          eventKind: 'run.mark',
          eventPayload: {'defId': 'a', 'completed': true},
        );
        loaded = (await ownStore.timersInBoard(b.id)).single;
        expect(
          loaded.updatedAt,
          ownClock.current
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          reason: 'run.mark leaves the modified stamp alone',
        );
      },
    );
  });

  group('schema v3 migration (P3.2)', () {
    test(
      'v2 timers gain folder placement + stamps; folders table lands',
      () async {
        final dir = Directory.systemTemp.createTempSync('planner_migration_v3');
        final file = File('${dir.path}/mig3.db');

        // Phase 1: a schemaVersion-2 database — timers WITHOUT the library
        // columns, no folders table — with one board + one timer.
        final v2 = PlannerDb(NativeDatabase(file));
        await v2.customStatement('DROP TABLE folders');
        await v2.customStatement('ALTER TABLE timers DROP COLUMN folder_id');
        await v2.customStatement('ALTER TABLE timers DROP COLUMN sort_index');
        await v2.customStatement('ALTER TABLE timers DROP COLUMN created_at');
        await v2.customStatement('ALTER TABLE timers DROP COLUMN updated_at');
        await v2.customStatement(
          "INSERT INTO boards (id, name) VALUES ('b1', 'My Board')",
        );
        await v2.customStatement(
          "INSERT INTO timers (id, board_id, name, color) "
          "VALUES ('t1', 'b1', 'Old timer', '#0055ff')",
        );
        await v2.customStatement('PRAGMA user_version = 2');
        await v2.close();

        // Phase 2: reopening under schema v3 runs the 2→3 migration and the
        // store reads the migrated row through the new mapping.
        final v3 = PlannerDb(NativeDatabase(file));
        final store3 = DriftStore(v3, clock);
        final migrated = (await store3.timersInBoard('b1')).single;
        expect(migrated.folderId, isNull); // folder-less at the library root
        expect(migrated.sortIndex, 1); // creation order (rowid) seeded
        expect(migrated.createdAt, greaterThan(0)); // migration-time stamp
        expect(migrated.updatedAt, greaterThan(0));
        expect(await store3.allFolders(), isEmpty); // table exists, empty

        // The migrated database accepts new library writes.
        final f = await store3.createFolder('Post-migration');
        expect((await store3.allFolders()).single.name, 'Post-migration');
        await store3.renameFolder(f.id, 'Still works');
        expect((await store3.allFolders()).single.name, 'Still works');
        await store3.close();

        dir.deleteSync(recursive: true);
      },
    );
  });

  group('schema v4 migration (P3.4)', () {
    test(
      'a v3 database gains default_rules; rules read/write after reopen',
      () async {
        final dir = Directory.systemTemp.createTempSync('planner_migration_v4');
        final file = File('${dir.path}/mig4.db');

        // Phase 1: a schemaVersion-3 database — the current shape minus
        // the default_rules table — with one board + one timer.
        final v3 = PlannerDb(NativeDatabase(file));
        await v3.customStatement('DROP TABLE default_rules');
        await v3.customStatement(
          "INSERT INTO boards (id, name) VALUES ('b1', 'My Board')",
        );
        await v3.customStatement(
          'INSERT INTO timers '
          '(id, board_id, name, color, sort_index, created_at, updated_at) '
          "VALUES ('t1', 'b1', 'Old plan', '#0055ff', 0, 1772000000000, "
          '1772000000000)',
        );
        await v3.customStatement('PRAGMA user_version = 3');
        await v3.close();

        // Phase 2: reopening under schema v4 runs the 3→4 migration —
        // the table lands (empty) and accepts new rule writes.
        final v4 = PlannerDb(NativeDatabase(file));
        final store4 = DriftStore(v4, clock);
        expect(await store4.rulesFor('t1'), isEmpty);

        final added = await store4.addRule(
          timerId: 't1',
          kind: DefaultRuleKind.monthday,
          value: 15,
          repeat: true,
        );
        final loaded = await store4.rulesFor('t1');
        expect(loaded.single.id, added.id);
        expect(loaded.single.kind, DefaultRuleKind.monthday);
        expect(loaded.single.value, 15);
        expect(loaded.single.repeat, isTrue);
        await store4.close();

        dir.deleteSync(recursive: true);
      },
    );
  });

  group('default rules (P3.4)', () {
    test(
      'every kind round-trips (manual enum mapping); re-add is idempotent',
      () async {
        final b = await store.createBoard('b');
        final t = await store.createTimer(
          boardId: b.id,
          name: 'Gym',
          color: '#0055ff',
        );

        final added = <DefaultRule>[
          await store.addRule(
            timerId: t.id,
            kind: DefaultRuleKind.globalDefault,
          ),
          await store.addRule(
            timerId: t.id,
            kind: DefaultRuleKind.weekday,
            value: 1, // Monday
            repeat: true,
          ),
          await store.addRule(
            timerId: t.id,
            kind: DefaultRuleKind.weekday,
            value: 20260303, // one-off: this Tuesday
          ),
          await store.addRule(
            timerId: t.id,
            kind: DefaultRuleKind.monthday,
            value: 15,
            repeat: true,
          ),
          await store.addRule(
            timerId: t.id,
            kind: DefaultRuleKind.monthday,
            value: 20260415, // one-off: this 15th
          ),
          await store.addRule(
            timerId: t.id,
            kind: DefaultRuleKind.date,
            value: 20260501,
          ),
        ];

        // Round-trip: same rows, creation order, every field intact —
        // and the kind survives the TEXT column (name-based mapping in
        // both directions, BLOCKERS #2).
        final loaded = await store.rulesFor(t.id);
        expect(loaded.map((r) => r.id), added.map((r) => r.id));
        expect(loaded.map((r) => r.kind), added.map((r) => r.kind));
        expect(loaded.map((r) => r.value), [
          null, // a global default stores no value
          1,
          20260303,
          15,
          20260415,
          20260501,
        ]);
        expect(loaded.map((r) => r.repeat), [
          false,
          true,
          false,
          true,
          false,
          false,
        ]);
        // The wire TEXT the schema actually stores (the manual enum map).
        final raw = await db.select(db.defaultRules).get();
        expect(raw.map((r) => r.kind), [
          'default',
          'weekday',
          'weekday',
          'monthday',
          'monthday',
          'date',
        ]);

        // Idempotent re-add: same rule → the SAME row, no new row, and
        // no second change-log event (a no-op is not a mutation).
        final againWeekday = await store.addRule(
          timerId: t.id,
          kind: DefaultRuleKind.weekday,
          value: 1,
          repeat: true,
        );
        final againOneOff = await store.addRule(
          timerId: t.id,
          kind: DefaultRuleKind.weekday,
          value: 20260303,
        );
        expect(againWeekday.id, added[1].id);
        expect(againOneOff.id, added[2].id);
        expect(await store.rulesFor(t.id), hasLength(6));
        final events = await store.events();
        expect(events.where((e) => e.kind == 'rule.add'), hasLength(6));

        // Remove drops the row and logs it; a second remove throws
        // (missing-row ops throw, like the other renames).
        await store.removeRule(added.first.id);
        expect(
          (await store.rulesFor(t.id)).map((r) => r.id),
          isNot(contains(added.first.id)),
        );
        expect(
          (await store.events()).map((e) => e.kind),
          containsAllInOrder(<String>['rule.add', 'rule.remove']),
        );
        await expectLater(
          store.removeRule('missing'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'plan deletes cascade to its rules; tree saves never touch them',
      () async {
        final b = await store.createBoard('b');
        final f = await store.createFolder('F');
        final inFolder = await store.createTimer(
          boardId: b.id,
          name: 'Routine',
          color: '#0055ff',
          folderId: f.id,
        );
        final atRoot = await store.createTimer(
          boardId: b.id,
          name: 'List',
          color: '#0055ff',
        );
        await store.addRule(
          timerId: inFolder.id,
          kind: DefaultRuleKind.weekday,
          value: 1,
          repeat: true,
        );
        await store.addRule(
          timerId: atRoot.id,
          kind: DefaultRuleKind.globalDefault,
        );

        // saveTree shares the def/group clear helper with the deletes —
        // a tree write must NOT wipe the plan's rules.
        await store.saveTree(
          atRoot.id,
          IntervalTree([
            DefNode(
              IntervalDef(
                id: 'a',
                timerId: atRoot.id,
                color: '#0055ff',
                durationSeconds: 10,
                autoFinish: true,
              ),
            ),
          ]),
          eventKind: 'tree.save',
        );
        expect(await store.rulesFor(atRoot.id), hasLength(1));

        // Folder cascade: the folder's plan loses its rules with it;
        // the root plan's survive.
        await store.deleteFolder(f.id);
        expect(await store.rulesFor(inFolder.id), isEmpty);
        expect(await store.rulesFor(atRoot.id), hasLength(1));

        // Direct plan delete cascades too.
        await store.deleteTimer(atRoot.id);
        expect(await store.rulesFor(atRoot.id), isEmpty);
      },
    );

    test('malformed rules are refused at the store', () async {
      final b = await store.createBoard('b');
      final t = await store.createTimer(
        boardId: b.id,
        name: 'x',
        color: '#0055ff',
      );

      await expectLater(
        store.addRule(
          timerId: t.id,
          kind: DefaultRuleKind.weekday,
          value: 9,
          repeat: true,
        ),
        throwsA(isA<StateError>()), // 1-7 only while repeating
      );
      await expectLater(
        store.addRule(
          timerId: t.id,
          kind: DefaultRuleKind.monthday,
          value: 0,
          repeat: true,
        ),
        throwsA(isA<StateError>()), // 1-31 only while repeating
      );
      await expectLater(
        store.addRule(timerId: t.id, kind: DefaultRuleKind.weekday),
        throwsA(isA<StateError>()), // value required
      );
      await expectLater(
        store.addRule(timerId: t.id, kind: DefaultRuleKind.date, value: 5),
        throwsA(isA<StateError>()), // not a YYYYMMDD day
      );
      await expectLater(
        store.addRule(timerId: t.id, kind: DefaultRuleKind.weekday, value: 123),
        throwsA(isA<StateError>()), // one-off ⇒ a YYYYMMDD day, not 1-7
      );
      expect(await store.rulesFor(t.id), isEmpty);

      // A global default carries no value — a stray one is normalized
      // away ("value: null for default"), not stored.
      final defaults = await store.addRule(
        timerId: t.id,
        kind: DefaultRuleKind.globalDefault,
        value: 42,
      );
      expect(defaults.value, isNull);
      expect((await store.rulesFor(t.id)).single.value, isNull);
    });
  });

  group('change log', () {
    test('every mutation appends an ordered, complete event', () async {
      final b = await store.createBoard('tmp');
      final t = await store.createTimer(
        boardId: b.id,
        name: 'chain',
        color: '#0055ff',
      );
      await store.saveTree(t.id, demoTree(t.id), eventKind: 'tree.save');
      await store.groupNodes(timerId: t.id, nodeIds: ['a', 'd']);
      await store.renameBoard(b.id, 'renamed');

      final events = await store.events();
      expect(events.map((e) => e.kind), [
        'board.create',
        'timer.create',
        'tree.save',
        'tree.group',
        'board.rename',
      ]);
      // Strictly increasing seq == insertion order; payloads are valid JSON.
      for (var i = 0; i < events.length; i++) {
        expect(events[i].seq, i + 1);
        expect(events[i].timestampMs, clock.now().millisecondsSinceEpoch);
        expect(events[i].payloadJson, startsWith('{'));
      }
      // Payload carries the op parameters.
      final groupEvent = events[3];
      expect(groupEvent.payloadJson, contains('"nodeIds"'));
      expect(groupEvent.payloadJson, contains('"timerId"'));
    });

    test(
      'deleteBoard cascade logs one timer.delete per timer, then board.delete',
      () async {
        final b = await store.createBoard('b');
        await store.createTimer(boardId: b.id, name: 't1', color: '#0055ff');
        await store.createTimer(boardId: b.id, name: 't2', color: '#ff00b1');

        await store.deleteBoard(b.id);

        final events = await store.events();
        expect(events.map((e) => e.kind), [
          'board.create',
          'timer.create',
          'timer.create',
          'timer.delete', // per-timer cascade events, in creation order
          'timer.delete',
          'board.delete', // last
        ]);
        // Cascade events carry the same payload shape as a plain deleteTimer.
        expect(events[3].payloadJson, contains('"timerId"'));
        expect(events[5].payloadJson, contains('"boardId"'));
      },
    );

    test('event seq is unique at the DB level', () async {
      await store.createBoard('x'); // consumes seq 1

      // A duplicate seq must violate a DB constraint — ordering is enforced
      // by the schema, not by convention.
      Object? caught;
      try {
        await db
            .into(db.eventLog)
            .insert(
              EventLogCompanion.insert(
                id: 'dup',
                seq: 1,
                timestampMs: 0,
                kind: 'x',
                payloadJson: '{}',
              ),
            );
      } catch (e) {
        caught = e;
      }
      expect(
        caught,
        isNotNull,
        reason: 'duplicate seq must violate the unique constraint',
      );
    });
  });
}

class FixedClock implements Clock {
  FixedClock(this.instant);
  final DateTime instant;
  @override
  DateTime now() => instant;
}

/// Mutable variant for the P3.2 stamp tests — virtual time is free, assign
/// [current] directly (the app-side fake's shape).
class MutableClock implements Clock {
  MutableClock(this.current);
  DateTime current;
  @override
  DateTime now() => current;
}

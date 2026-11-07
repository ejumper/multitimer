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
    test('v1 rows carry over: mark from completion_default, trigger dropped',
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

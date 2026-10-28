/// The drift-backed [Store]. Constructed by the app:
/// `DriftStore(PlannerDb(openSqliteFile(path)), clock)`.
///
/// Tree ops are load → domain transform ([IntervalTree]) → `saveTree` in one
/// transaction, so structural semantics live only in the domain. Every
/// mutation appends exactly one change-log event (D4), timestamped by the
/// injected [Clock].
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../clock.dart';
import '../model/entities.dart';
import '../model/event_log.dart';
import '../model/group_def.dart';
import '../model/interval_def.dart';
import '../model/tree.dart';
import '../uuid.dart';
import 'planner_db.dart';
import 'store.dart';

/// Signature for the engine's id generator (defaults to [newUuidV4]).
typedef GenerateUuid = String Function();

CompletionState _parseCompletion(String s) => CompletionState.values.byName(s);

TriggerMethod _parseTrigger(String s) => TriggerMethod.values.byName(s);

class DriftStore implements Store {
  // ignore: prefer_initializing_formals, the default is a function tear-off
  // (not const), so an initializing formal is impossible here.
  DriftStore(this._db, this._clock, {GenerateUuid newId = newUuidV4})
    // ignore: prefer_initializing_formals
    : newId = newId;

  final PlannerDb _db;
  final Clock _clock;
  final GenerateUuid newId;

  int _nowMs() => _clock.now().millisecondsSinceEpoch;

  // ── boards ──────────────────────────────────────────────────────────────

  @override
  Future<List<Board>> allBoards() async {
    final rows = await _db.select(_db.boards).get();
    return [for (final r in rows) Board(id: r.id, name: r.name)];
  }

  @override
  Future<Board> createBoard(String name) async {
    final board = Board(id: newId(), name: name);
    await _db.transaction(() async {
      await _db
          .into(_db.boards)
          .insert(BoardsCompanion.insert(id: board.id, name: board.name));
      await _appendEvent('board.create', {'boardId': board.id, 'name': name});
    });
    return board;
  }

  @override
  Future<void> renameBoard(String id, String name) async {
    await _db.transaction(() async {
      final rows = await (_db.select(
        _db.boards,
      )..where((t) => t.id.equals(id))).get();
      if (rows.isEmpty) throw StateError('board not found: $id');
      await (_db.update(_db.boards)..where((t) => t.id.equals(id))).write(
        BoardsCompanion(name: Value(name)),
      );
      await _appendEvent('board.rename', {'boardId': id, 'name': name});
    });
  }

  @override
  Future<void> deleteBoard(String id) async {
    await _db.transaction(() async {
      final timers = await (_db.select(
        _db.timers,
      )..where((t) => t.boardId.equals(id))).get();
      // Cascade is logged per object (same event + payload shape as
      // deleteTimer), so the change log stays complete for a future sync
      // consumer; board.delete comes last.
      for (final t in timers) {
        await _deleteTimerRows(t.id);
        await _appendEvent('timer.delete', {'timerId': t.id});
      }
      await (_db.delete(_db.timers)..where((t) => t.boardId.equals(id))).go();
      await (_db.delete(_db.boards)..where((t) => t.id.equals(id))).go();
      await _appendEvent('board.delete', {'boardId': id});
    });
  }

  // ── interval timers ─────────────────────────────────────────────────────

  @override
  Future<List<IntervalTimer>> timersInBoard(String boardId) async {
    final rows = await (_db.select(
      _db.timers,
    )..where((t) => t.boardId.equals(boardId))).get();
    return [
      for (final r in rows)
        IntervalTimer(
          id: r.id,
          boardId: r.boardId,
          name: r.name,
          color: r.color,
        ),
    ];
  }

  @override
  Future<IntervalTimer> createTimer({
    required String boardId,
    required String name,
    required String color,
  }) async {
    final timer = IntervalTimer(
      id: newId(),
      boardId: boardId,
      name: name,
      color: color,
    );
    await _db.transaction(() async {
      await _db
          .into(_db.timers)
          .insert(
            TimersCompanion.insert(
              id: timer.id,
              boardId: timer.boardId,
              name: timer.name,
              color: timer.color,
            ),
          );
      await _appendEvent('timer.create', {
        'timerId': timer.id,
        'boardId': boardId,
        'name': name,
        'color': color,
      });
    });
    return timer;
  }

  @override
  Future<void> updateTimer(String id, {String? name, String? color}) async {
    await _db.transaction(() async {
      final rows = await (_db.select(
        _db.timers,
      )..where((t) => t.id.equals(id))).get();
      if (rows.isEmpty) throw StateError('timer not found: $id');
      final changes = <String, Object?>{'name': ?name, 'color': ?color};
      await (_db.update(_db.timers)..where((t) => t.id.equals(id))).write(
        TimersCompanion(
          name: name == null ? const Value.absent() : Value(name),
          color: color == null ? const Value.absent() : Value(color),
        ),
      );
      await _appendEvent('timer.update', {'timerId': id, ...changes});
    });
  }

  @override
  Future<void> deleteTimer(String id) async {
    await _db.transaction(() async {
      await _deleteTimerRows(id);
      await _appendEvent('timer.delete', {'timerId': id});
    });
  }

  Future<void> _deleteTimerRows(String timerId) async {
    await (_db.delete(
      _db.intervalDefs,
    )..where((t) => t.timerId.equals(timerId))).go();
    await (_db.delete(
      _db.groupDefs,
    )..where((t) => t.timerId.equals(timerId))).go();
  }

  // ── interval tree ───────────────────────────────────────────────────────

  @override
  Future<IntervalTree> loadTree(String timerId) async {
    final defRows = await (_db.select(
      _db.intervalDefs,
    )..where((t) => t.timerId.equals(timerId))).get();
    final groupRows = await (_db.select(
      _db.groupDefs,
    )..where((t) => t.timerId.equals(timerId))).get();

    final defNodes = {
      for (final r in defRows)
        r.id: DefNode(
          IntervalDef(
            id: r.id,
            timerId: r.timerId,
            name: r.name,
            color: r.color,
            durationSeconds: r.durationSeconds,
            autoFinish: r.autoFinish,
            endAlertSoundFile: r.endAlertSoundFile,
            completionDefault: _parseCompletion(r.completionDefault),
            trigger: _parseTrigger(r.trigger),
          ),
        ),
    };

    // saveTree assigns positions from ONE combined counter per parent (a
    // child's index among its siblings, whatever its kind), so loading is a
    // merge by that index. Recursion terminates because persisted trees are
    // acyclic by construction; a corrupt/cyclic row set would stack-overflow
    // here rather than load garbage.
    List<IntervalNode> buildChildren(String? parentId) {
      final merged = <MapEntry<int, IntervalNode>>[
        for (final d in defRows.where((d) => d.parentGroupId == parentId))
          MapEntry(d.sortIndex, defNodes[d.id]!),
        for (final g in groupRows.where((g) => g.parentGroupId == parentId))
          MapEntry(
            g.orderIndex,
            GroupNode(
              GroupDef(
                id: g.id,
                timerId: g.timerId,
                repeatCount: g.repeatCount,
              ),
              buildChildren(g.id),
            ),
          ),
      ]..sort((a, b) => a.key.compareTo(b.key));
      return [for (final e in merged) e.value];
    }

    return IntervalTree(buildChildren(null));
  }

  @override
  Future<void> saveTree(
    String timerId,
    IntervalTree tree, {
    required String eventKind,
    Map<String, Object?> eventPayload = const {},
  }) async {
    final defRows = <IntervalDefsCompanion>[];
    final groupRows = <GroupDefsCompanion>[];

    void walk(List<IntervalNode> nodes, String? parentGroupId) {
      for (var i = 0; i < nodes.length; i++) {
        final n = nodes[i];
        switch (n) {
          case DefNode(:final def):
            if (def.timerId != timerId) {
              throw StateError(
                'saveTree: def ${def.id} belongs to ${def.timerId}, not $timerId',
              );
            }
            defRows.add(
              IntervalDefsCompanion.insert(
                id: def.id,
                timerId: def.timerId,
                name: Value(def.name),
                color: def.color,
                durationSeconds: def.durationSeconds,
                autoFinish: def.autoFinish,
                endAlertSoundFile: Value(def.endAlertSoundFile),
                parentGroupId: Value(parentGroupId),
                sortIndex: i,
                completionDefault: def.completionDefault.name,
                trigger: def.trigger.name,
              ),
            );
          case GroupNode(:final group, :final children):
            if (group.timerId != timerId) {
              throw StateError(
                'saveTree: group ${group.id} belongs to ${group.timerId}, not $timerId',
              );
            }
            groupRows.add(
              GroupDefsCompanion.insert(
                id: group.id,
                timerId: group.timerId,
                repeatCount: group.repeatCount,
                parentGroupId: Value(parentGroupId),
                orderIndex: i,
              ),
            );
            walk(children, group.id);
        }
      }
    }

    walk(tree.roots, null);

    await _db.transaction(() async {
      await _deleteTimerRows(timerId);
      for (final r in defRows) {
        await _db.into(_db.intervalDefs).insert(r);
      }
      for (final r in groupRows) {
        await _db.into(_db.groupDefs).insert(r);
      }
      await _appendEvent(eventKind, {'timerId': timerId, ...eventPayload});
    });
  }

  @override
  Future<IntervalTree> groupNodes({
    required String timerId,
    required List<String> nodeIds,
    int repeatCount = 1,
  }) async {
    final tree = await loadTree(timerId);
    final next = tree.grouped(
      nodeIds,
      newGroupId: newId(),
      repeatCount: repeatCount,
    );
    await saveTree(
      timerId,
      next,
      eventKind: 'tree.group',
      eventPayload: {'nodeIds': nodeIds, 'repeatCount': repeatCount},
    );
    return next;
  }

  @override
  Future<IntervalTree> ungroupNode({
    required String timerId,
    required String groupId,
  }) async {
    final tree = await loadTree(timerId);
    final next = tree.ungrouped(groupId);
    await saveTree(
      timerId,
      next,
      eventKind: 'tree.ungroup',
      eventPayload: {'groupId': groupId},
    );
    return next;
  }

  @override
  Future<IntervalTree> duplicateNodes({
    required String timerId,
    required List<String> nodeIds,
  }) async {
    final tree = await loadTree(timerId);
    final newIds = <String>[];
    final next = tree.duplicated(
      nodeIds,
      newId: () {
        final id = newId();
        newIds.add(id);
        return id;
      },
    );
    await saveTree(
      timerId,
      next,
      eventKind: 'tree.duplicate',
      eventPayload: {'nodeIds': nodeIds, 'newIds': newIds},
    );
    return next;
  }

  @override
  Future<IntervalTree> deleteNodes({
    required String timerId,
    required List<String> nodeIds,
  }) async {
    final tree = await loadTree(timerId);
    final next = tree.withoutNodes(nodeIds);
    await saveTree(
      timerId,
      next,
      eventKind: 'tree.delete',
      eventPayload: {'nodeIds': nodeIds},
    );
    return next;
  }

  @override
  Future<IntervalTree> moveNode({
    required String timerId,
    required String nodeId,
    required String? newParentGroupId,
    required int newIndex,
  }) async {
    final tree = await loadTree(timerId);
    final next = tree.moved(
      nodeId,
      newParentGroupId: newParentGroupId,
      newIndex: newIndex,
    );
    await saveTree(
      timerId,
      next,
      eventKind: 'tree.move',
      eventPayload: {
        'nodeId': nodeId,
        'newParentGroupId': newParentGroupId,
        'newIndex': newIndex,
      },
    );
    return next;
  }

  // ── change log ──────────────────────────────────────────────────────────

  @override
  Future<List<EventLogEntry>> events() async {
    final rows = await (_db.select(
      _db.eventLog,
    )..orderBy([(u) => OrderingTerm.asc(u.seq)])).get();
    return [
      for (final r in rows)
        EventLogEntry(
          id: r.id,
          seq: r.seq,
          timestampMs: r.timestampMs,
          kind: r.kind,
          payloadJson: r.payloadJson,
        ),
    ];
  }

  Future<void> _appendEvent(
    String kind,
    Map<String, Object?> payload, {
    int? timestampMs,
  }) async {
    // Monotonic seq under concurrency is fine: all mutations run through the
    // same serialized transaction queue in practice (single app process).
    final maxExpr = _db.eventLog.seq.max();
    final maxRow = await (_db.selectOnly(
      _db.eventLog,
    )..addColumns([maxExpr])).getSingle();
    final nextSeq = (maxRow.read(maxExpr) ?? 0) + 1;

    await _db
        .into(_db.eventLog)
        .insert(
          EventLogCompanion.insert(
            id: newId(),
            seq: nextSeq,
            timestampMs: timestampMs ?? _nowMs(),
            kind: kind,
            payloadJson: jsonEncode(payload),
          ),
        );
  }

  @override
  Future<void> appendEvent({
    required String kind,
    required int timestampMs,
    Map<String, Object?> payload = const {},
  }) => _appendEvent(kind, payload, timestampMs: timestampMs);

  @override
  Future<void> close() => _db.close();
}

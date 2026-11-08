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
import '../model/resolve.dart';
import '../model/tree.dart';
import '../uuid.dart';
import 'planner_db.dart';
import 'store.dart';

/// Signature for the engine's id generator (defaults to [newUuidV4]).
typedef GenerateUuid = String Function();

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
        await _deleteRuleRows(t.id);
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
          folderId: r.folderId,
          sortIndex: r.sortIndex,
          createdAt: r.createdAt,
          updatedAt: r.updatedAt,
          dayDate: r.dayDate,
          originPlanId: r.originPlanId,
        ),
    ];
  }

  @override
  Future<IntervalTimer> createTimer({
    required String boardId,
    required String name,
    required String color,
    String? folderId,
    int? dayDate,
  }) => _db.transaction(() async {
    // Land on TOP of the folder's ordered plans (the "new list" rule,
    // P3.2): ascending sort order, so one below the current minimum.
    final siblings =
        await (_db.select(_db.timers)
              ..where(
                (t) => folderId == null
                    ? t.folderId.isNull()
                    : t.folderId.equals(folderId),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
            .get();
    final sortIndex = siblings.isEmpty ? 0 : siblings.first.sortIndex - 1;
    final nowMs = _nowMs();
    final timer = IntervalTimer(
      id: newId(),
      boardId: boardId,
      name: name,
      color: color,
      folderId: folderId,
      sortIndex: sortIndex,
      createdAt: nowMs,
      updatedAt: nowMs,
      dayDate: dayDate,
    );
    await _db
        .into(_db.timers)
        .insert(
          TimersCompanion.insert(
            id: timer.id,
            boardId: timer.boardId,
            name: timer.name,
            color: timer.color,
            folderId: Value(folderId),
            sortIndex: sortIndex,
            createdAt: nowMs,
            updatedAt: nowMs,
            dayDate: Value(dayDate),
          ),
        );
    await _appendEvent('timer.create', {
      'timerId': timer.id,
      'boardId': boardId,
      'name': name,
      'color': color,
      'folderId': folderId,
    });
    return timer;
  });

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
          // The Library row's modified stamp (P3.2): a rename/edit bumps it.
          updatedAt: Value(_nowMs()),
        ),
      );
      await _appendEvent('timer.update', {'timerId': id, ...changes});
    });
  }

  @override
  Future<void> deleteTimer(String id) async {
    await _db.transaction(() async {
      await _deleteTimerRows(id);
      await _deleteRuleRows(id);
      // The plan itself — without this the delete is a silent no-op and
      // the plan survives its own deletion (P3.2 bug caught by tests).
      await (_db.delete(_db.timers)..where((t) => t.id.equals(id))).go();
      await _appendEvent('timer.delete', {'timerId': id});
    });
  }

  /// Clears a timer's defs + groups. Also used by saveTree as its
  /// clear-before-insert step — the TIMERS row itself is the callers'
  /// business (deleteTimer deletes it; the cascades delete theirs in bulk).
  Future<void> _deleteTimerRows(String timerId) async {
    await (_db.delete(
      _db.intervalDefs,
    )..where((t) => t.timerId.equals(timerId))).go();
    await (_db.delete(
      _db.groupDefs,
    )..where((t) => t.timerId.equals(timerId))).go();
  }

  /// Clears a timer's default rules — the DELETE cascades only
  /// (deleteTimer / deleteBoard / deleteFolder). NOT part of
  /// [_deleteTimerRows]: saveTree reuses that as its clear-before-insert
  /// step, and tree writes must never wipe the plan's rules.
  Future<void> _deleteRuleRows(String timerId) => (_db.delete(
    _db.defaultRules,
  )..where((t) => t.timerId.equals(timerId))).go();

  // ── library folders (v2 P3.2) ─────────────────────────────────────────

  @override
  Future<List<Folder>> allFolders() async {
    final rows = await (_db.select(
      _db.folders,
    )..orderBy([(t) => OrderingTerm.asc(t.sortIndex)])).get();
    return [for (final r in rows) Folder(id: r.id, name: r.name)];
  }

  @override
  Future<Folder> createFolder(String name) async {
    return _db.transaction(() async {
      final rows = await _db.select(_db.folders).get();
      var next = 0;
      for (final r in rows) {
        if (r.sortIndex + 1 > next) next = r.sortIndex + 1;
      }
      final folder = Folder(id: newId(), name: name);
      await _db
          .into(_db.folders)
          .insert(
            FoldersCompanion.insert(id: folder.id, name: name, sortIndex: next),
          );
      await _appendEvent('folder.create', {
        'folderId': folder.id,
        'name': name,
      });
      return folder;
    });
  }

  @override
  Future<void> renameFolder(String id, String name) async {
    await _db.transaction(() async {
      final rows = await (_db.select(
        _db.folders,
      )..where((t) => t.id.equals(id))).get();
      if (rows.isEmpty) throw StateError('folder not found: $id');
      await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
        FoldersCompanion(name: Value(name)),
      );
      await _appendEvent('folder.rename', {'folderId': id, 'name': name});
    });
  }

  @override
  Future<void> deleteFolder(String id) async {
    await _db.transaction(() async {
      // Cascade, logged per plan exactly like deleteBoard's timers: the
      // change log stays complete for a future sync consumer.
      final timers = await (_db.select(
        _db.timers,
      )..where((t) => t.folderId.equals(id))).get();
      for (final t in timers) {
        await _deleteTimerRows(t.id);
        await _deleteRuleRows(t.id);
        await _appendEvent('timer.delete', {'timerId': t.id});
      }
      await (_db.delete(_db.timers)..where((t) => t.folderId.equals(id))).go();
      await (_db.delete(_db.folders)..where((t) => t.id.equals(id))).go();
      await _appendEvent('folder.delete', {'folderId': id});
    });
  }

  @override
  Future<void> moveTimer({
    required String timerId,
    required String? toFolderId,
    required int toIndex,
  }) async {
    await _db.transaction(() async {
      final rows = await _db.select(_db.timers).get();
      final matches = rows.where((r) => r.id == timerId);
      if (matches.isEmpty) throw StateError('timer not found: $timerId');
      final moved = matches.first;

      List<String> idsIn(String? folderId) {
        final children =
            rows
                .where((r) => r.folderId == folderId && r.id != timerId)
                .toList()
              ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
        return [for (final r in children) r.id];
      }

      final sameFolder = moved.folderId == toFolderId;
      final sourceIds = idsIn(moved.folderId);
      final targetIds = sameFolder ? [...sourceIds] : idsIn(toFolderId);
      final at = toIndex.clamp(0, targetIds.length);
      targetIds.insert(at, timerId);

      Future<void> renumber(List<String> ids, String? folderId) async {
        for (var i = 0; i < ids.length; i++) {
          await (_db.update(
            _db.timers,
          )..where((t) => t.id.equals(ids[i]))).write(
            TimersCompanion(folderId: Value(folderId), sortIndex: Value(i)),
          );
        }
      }

      await renumber(targetIds, toFolderId);
      if (!sameFolder) await renumber(sourceIds, moved.folderId);

      await _appendEvent('timer.move', {
        'timerId': timerId,
        'toFolderId': toFolderId,
        'toIndex': at,
      });
    });
  }

  // ── default rules (v2 P3.4) ────────────────────────────────────────

  /// Enum mapping (BLOCKERS #2: drift's `textEnum` breaks codegen) —
  /// [DefaultRuleKind] ⇄ its TEXT wire value, in both directions.
  DefaultRule _ruleFromRow(DefaultRuleRow r) => DefaultRule(
    id: r.id,
    timerId: r.timerId,
    kind: DefaultRuleKind.fromWireName(r.kind),
    value: r.value,
    repeat: r.repeat,
  );

  @override
  Future<List<DefaultRule>> rulesFor(String timerId) async {
    // Creation order (SQLite rowid): the menu lists rules oldest first.
    final rows =
        await (_db.select(_db.defaultRules)
              ..where((t) => t.timerId.equals(timerId))
              ..orderBy([(t) => OrderingTerm.asc(t.rowId)]))
            .get();
    return [for (final r in rows) _ruleFromRow(r)];
  }

  @override
  Future<DefaultRule> addRule({
    required String timerId,
    required DefaultRuleKind kind,
    int? value,
    bool repeat = false,
  }) async {
    // A global default stores value = null whatever was passed — the
    // column's meaning is kind-dependent (see [DefaultRule]).
    final storedValue = kind == DefaultRuleKind.globalDefault ? null : value;
    _validateRule(kind, storedValue, repeat);
    return _db.transaction(() async {
      // Idempotent re-add (P3.4): the same rule exists → hand it back
      // untouched (no row, no event — a no-op is not a mutation).
      final existing =
          await (_db.select(_db.defaultRules)
                ..where((t) => t.timerId.equals(timerId))
                ..where((t) => t.kind.equals(kind.wireName))
                ..where(
                  (t) => storedValue == null
                      ? t.value.isNull()
                      : t.value.equals(storedValue),
                )
                ..where((t) => t.repeat.equals(repeat)))
              .getSingleOrNull();
      if (existing != null) return _ruleFromRow(existing);

      final rule = DefaultRule(
        id: newId(),
        timerId: timerId,
        kind: kind,
        value: storedValue,
        repeat: repeat,
      );
      await _db
          .into(_db.defaultRules)
          .insert(
            DefaultRulesCompanion.insert(
              id: rule.id,
              timerId: rule.timerId,
              kind: rule.kind.wireName,
              value: Value(rule.value),
              repeat: rule.repeat,
            ),
          );
      await _appendEvent('rule.add', {
        'ruleId': rule.id,
        'timerId': timerId,
        'kind': kind.wireName,
        'value': storedValue,
        'repeat': repeat,
      });
      return rule;
    });
  }

  @override
  Future<void> removeRule(String ruleId) => _db.transaction(() async {
    final rows = await (_db.select(
      _db.defaultRules,
    )..where((t) => t.id.equals(ruleId))).get();
    if (rows.isEmpty) throw StateError('rule not found: $ruleId');
    await (_db.delete(
      _db.defaultRules,
    )..where((t) => t.id.equals(ruleId))).go();
    final rule = _ruleFromRow(rows.single);
    await _appendEvent('rule.remove', {
      'ruleId': ruleId,
      'timerId': rule.timerId,
      'kind': rule.kind.wireName,
      'value': rule.value,
      'repeat': rule.repeat,
    });
  });

  /// Refuses malformed rules at the store seam — [addRule]'s contract.
  /// `value` arrives pre-normalized (null for a global default).
  void _validateRule(DefaultRuleKind kind, int? value, bool repeat) {
    if (kind == DefaultRuleKind.globalDefault) return; // no value applies
    if (value == null) {
      throw StateError('default rule (${kind.wireName}): value is required');
    }
    if (kind == DefaultRuleKind.weekday && repeat && (value < 1 || value > 7)) {
      throw StateError(
        'default rule: weekday value must be 1-7 (Monday=1), got $value',
      );
    }
    if (kind == DefaultRuleKind.monthday &&
        repeat &&
        (value < 1 || value > 31)) {
      throw StateError('default rule: monthday value must be 1-31, got $value');
    }
    // One-off rules (repeat = false) and every date rule claim a full day.
    final needsDay =
        kind == DefaultRuleKind.date ||
        ((kind == DefaultRuleKind.weekday ||
                kind == DefaultRuleKind.monthday) &&
            !repeat);
    if (needsDay && !_isYyyyMmDd(value)) {
      throw StateError('default rule: expected a YYYYMMDD day, got $value');
    }
  }

  // ── days (v2 P4.1) ──────────────────────────────────────────────────

  Future<DayRow?> _dayRow(int day) => (_db.select(
    _db.days,
  )..where((t) => t.date.equals(day))).getSingleOrNull();

  Future<TimerRow?> _timerRow(String timerId) => (_db.select(
    _db.timers,
  )..where((t) => t.id.equals(timerId))).getSingleOrNull();

  /// The pure rule winner over ALL plans' rules — the placeholder a day
  /// with no explicit pin renders ([resolvePlanFor], order-independent).
  Future<String?> _ruleWinner(DateTime date) async {
    final rows = await _db.select(_db.defaultRules).get();
    return resolvePlanFor(
      rules: [for (final r in rows) _ruleFromRow(r)],
      date: date,
    );
  }

  @override
  Future<String?> dayPlanId(DateTime date) async {
    final row = await _dayRow(dayNumber(date));
    return row?.planTimerId;
  }

  @override
  Future<void> setDayPlan(DateTime date, String? timerId) => _db.transaction(
    () async {
      final day = dayNumber(date);
      await (_db.delete(_db.days)..where((t) => t.date.equals(day))).go();
      await _db
          .into(_db.days)
          .insert(DaysCompanion.insert(date: Value(day), planTimerId: Value(timerId)));
      await _appendEvent('day.setPlan', {'date': day, 'planTimerId': timerId});
    },
  );

  @override
  Future<String?> resolveDayPlan(DateTime date) async {
    final pinned = await dayPlanId(date); // the explicit pin, read-only
    if (pinned != null) return pinned;
    return _ruleWinner(date);
  }

  @override
  Future<String?> materializeDay(DateTime date) => _db.transaction<String?>(
    () async {
      final day = dayNumber(date);

      // Already the day's own timer? (The idempotence guard: a day row
      // pointing at a timer whose dayDate == this day IS the fork.)
      final pinned = (await _dayRow(day))?.planTimerId;
      if (pinned != null) {
        final pinnedTimer = await _timerRow(pinned);
        if (pinnedTimer != null && pinnedTimer.dayDate == day) {
          return pinnedTimer.id;
        }
      }

      // Source: the explicit pin when it still exists, else the rule winner
      // — same precedence as resolveDayPlan, i.e. exactly the placeholder
      // the day renders right now.
      String? sourceId = pinned;
      if (sourceId != null && await _timerRow(sourceId) == null) {
        sourceId = null;
      }
      sourceId ??= await _ruleWinner(date);
      if (sourceId == null) return null; // nothing claims the day
      final source = await _timerRow(sourceId);
      if (source == null) return null; // dangling rule (deleted plan)

      // The day's OWN timer: same board/name/color as the source, at the
      // library root (folderId null), carrying the day + its lineage.
      final forkId = newId();
      final nowMs = _nowMs();
      final siblings =
          await (_db.select(_db.timers)
                ..where((t) => t.folderId.isNull())
                ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
              .get();
      final sortIndex = siblings.isEmpty ? 0 : siblings.first.sortIndex - 1;
      await _db
          .into(_db.timers)
          .insert(
            TimersCompanion.insert(
              id: forkId,
              boardId: source.boardId,
              name: source.name,
              color: source.color,
              folderId: const Value(null),
              sortIndex: sortIndex,
              createdAt: nowMs,
              updatedAt: nowMs,
              dayDate: Value(day),
              originPlanId: Value(source.id),
            ),
          );

      // The fork rule (P1.1): the source's tree AS IT STANDS — fresh ids
      // everywhere, completion marks cleared — owned by the copy.
      final sourceTree = await loadTree(source.id);
      await saveTree(
        forkId,
        sourceTree.copiedToTimer(forkId, newId),
        eventKind: 'day.materialize',
        eventPayload: {'date': day, 'originPlanId': source.id},
      );

      // Point the day at its own copy (upsert: the row may or may not
      // exist yet — an unresolved day has no row, a pinned one does).
      await (_db.delete(_db.days)..where((t) => t.date.equals(day))).go();
      await _db
          .into(_db.days)
          .insert(DaysCompanion.insert(date: Value(day), planTimerId: Value(forkId)));
      return forkId;
    },
  );

  @override
  Future<int> dayItemCount(DateTime date) async {
    // Read-through: resolve + count, never materialize (a count is a
    // read — P4.2's calendar counts ride this without forking days).
    final planId = await resolveDayPlan(date);
    if (planId == null) return 0;
    final tree = await loadTree(planId);
    return tree.allNodes.whereType<DefNode>().length;
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
            completed: r.completed,
            triggerTimeSeconds: r.triggerTimeSeconds,
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
                durationSeconds: Value(def.durationSeconds),
                autoFinish: def.autoFinish,
                endAlertSoundFile: Value(def.endAlertSoundFile),
                parentGroupId: Value(parentGroupId),
                sortIndex: i,
                completed: def.completed,
                triggerTimeSeconds: Value(def.triggerTimeSeconds),
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
      // The modified stamp (P3.2): authored writes bump it — EXCEPT
      // completion marks (`run.mark`), which are execution, not authoring
      // (the Library row's date must not churn while a list is in use).
      if (eventKind != 'run.mark') {
        await (_db.update(_db.timers)..where((t) => t.id.equals(timerId)))
            .write(TimersCompanion(updatedAt: Value(_nowMs())));
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

/// Structural check for the YYYYMMDD day encoding of one-off/date rule
/// values: a plausible year (≥ 1000), month 1–12, day 1–31 — not a full
/// calendar validation (a day that never occurs simply never resolves).
bool _isYyyyMmDd(int value) {
  final year = value ~/ 10000;
  final month = (value ~/ 100) % 100;
  final day = value % 100;
  return year >= 1000 && month >= 1 && month <= 12 && day >= 1 && day <= 31;
}

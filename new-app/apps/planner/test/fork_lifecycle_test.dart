import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/bottom_bar.dart';
import 'package:planner/day_navigation.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// The P4.3 acceptance story as ONE test — the lazy-fork lifecycle in
/// full (OVERVIEW §6 / PLAN P4.3 rule 4):
///
/// open TOMORROW read-only (no `days` row) → check an item (materializes
/// exactly once, the mark lands on the COPY) → edit the ROUTINE in the
/// library (`saveTree` on the placeholder plan) → the day AFTER tomorrow
/// resolves the EDITED routine (the placeholder picks edits up by
/// arrival, still read-only) while tomorrow's fork is FROZEN — original
/// names, mark intact, still the board's timer → yesterday's fork
/// untouched.
///
/// Fixture: `Routine` (`r1 Breakfast 600s`, `r2 Stretch` Open) claiming
/// every day via a GLOBAL DEFAULT rule — no pins, so any `days` row is a
/// materialization. Yesterday is forked up front as the already-LIVED
/// day. All dates derive from the clock through [dayOf] — the same
/// local-midnight form `init(dayDate:)` speaks.
///
/// The board's 1 Hz ticker hangs pumpAndSettle — every pump here is
/// bounded through [settle] (`tester.pump()` [+ 300ms] rounds).
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late IntervalTimer routine;

  /// Today on the clock — the story's day anchor.
  DateTime today() => dayOf(clock.now());

  Future<void> buildFixture() async {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);

    final board = await store.createBoard('My Board');
    routine = await store.createTimer(
      boardId: board.id,
      name: 'Routine',
      color: '#0055ff',
    );
    await store.saveTree(
      routine.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'r1',
            timerId: routine.id,
            name: 'Breakfast',
            color: '#0055ff',
            durationSeconds: 600,
            autoFinish: true,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'r2',
            timerId: routine.id,
            name: 'Stretch',
            color: '#0055ff',
            durationSeconds: null, // Open
            autoFinish: false,
          ),
        ),
      ]),
      eventKind: 'tree.save',
    );
    await store.addRule(
      timerId: routine.id,
      kind: DefaultRuleKind.globalDefault,
    );
  }

  setUp(buildFixture);

  /// Bounded settle — the ticker/pulse hang pumpAndSettle. Rounds of
  /// `pump()` + 300ms cover the route transitions (150ms), the chevron
  /// reveal, and the store's async chains between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// A day-bound controller over this fixture's store (every one is
  /// disposed by the test that asked for it).
  AppController makeController() => AppController(
    store: store,
    clock: clock,
    notifier: RecordingNotifier(),
    player: RecordingPlayer(),
    soundsDir: '/sounds',
    soundListing: () => const [],
  );

  /// [id]'s tree — the story's day-plan ids come back nullable from the
  /// store, and every use below is already guarded by an isNotNull pin,
  /// so one load seam keeps the comparisons promotion-free.
  Future<IntervalTree> loadOrNull(String? id) async {
    if (id == null) return IntervalTree(const []);
    return await store.loadTree(id);
  }

  /// How many times [date] materialized — the `day.materialize` events
  /// carry the day number in their payload, so each day counts alone
  /// (yesterday's pre-story fork must not leak into tomorrow's count).
  Future<int> materializationsOf(DateTime date) async =>
      (await store.events())
          .where(
            (e) =>
                e.kind == 'day.materialize' &&
                (jsonDecode(e.payloadJson) as Map)['date'] ==
                    dayNumber(date),
          )
          .length;

  /// The plan's def names, in tree order — the frozen copies read their
  /// names off the store, never off the ids (a fork's are fresh).
  List<String> names(IntervalTree tree) => [
    for (final node in tree.allNodes.whereType<DefNode>())
      node.def.name ?? '',
  ];

  IntervalDef defNamed(IntervalTree tree, String name) => tree
      .allNodes
      .whereType<DefNode>()
      .map((n) => n.def)
      .firstWhere((d) => d.name == name);

  /// A tree's full content fingerprint (ids, shape, tint, marks) — the
  /// "frozen / untouched" comparisons read equality off this.
  List<String> describeTree(IntervalTree tree) => [
    for (final node in tree.allNodes)
      switch (node) {
        DefNode(:final def) =>
          'def ${def.id} ${def.name} ${def.color} ${def.durationSeconds} '
          '${def.autoFinish} ${def.completed} ${def.triggerTimeSeconds} '
          '${def.endAlertSoundFile}',
        GroupNode(:final group, :final children) =>
          'group ${group.id} ${group.timerId} ${group.repeatCount} '
          '${children.length}',
      },
  ];

  testWidgets('lazy_fork_lifecycle_open_check_edit_freezes_lived_days', (
    tester,
  ) async {
    final day0 = today();
    final yesterday = addDays(day0, -1);
    final tomorrow = addDays(day0, 1);
    final dayAfter = addDays(day0, 2);

    // YESTERDAY already LIVED: its private copy froze at materialization
    // — before anything below edits the Routine.
    final yesterdayFork = await store.materializeDay(yesterday);
    expect(yesterdayFork, isNotNull);
    final yesterdayFrozen = describeTree(await loadOrNull(yesterdayFork));
    expect(await materializationsOf(yesterday), 1);

    // 1 — open TOMORROW READ-ONLY: the placeholder's rows render, the
    //     days table has no row for it, and the only fork anywhere is
    //     yesterday's.
    final dayController = makeController();
    await dayController.init(dayDate: tomorrow);
    await tester.pumpWidget(
      MaterialApp(home: BoardScreen(dayController, bar: BoardBar.plan)),
    );
    await settle(tester);
    expect(find.byKey(const Key('row-r1')), findsOneWidget);
    expect(
      await store.dayPlanId(tomorrow),
      isNull,
      reason: 'a read-only open writes no rows',
    );
    expect(await materializationsOf(tomorrow), 0);
    expect(
      (await store.timersInBoard(dayController.board.id))
          .where((t) => t.dayDate != null),
      hasLength(1),
      reason: 'yesterday\u2019s copy is the only day timer so far',
    );

    // 2 — a CHECK is the day's first write: materializes EXACTLY once
    //     and the mark lands on the COPY (the placeholder stays clean).
    await tester.tap(find.byKey(const Key('check-r1')));
    await settle(tester);
    final forkId = await store.dayPlanId(tomorrow);
    expect(forkId, isNotNull);
    expect(forkId, isNot(routine.id));
    expect(dayController.timer.id, forkId, reason: 'the board rebinds');
    expect(await materializationsOf(tomorrow), 1);
    expect(
      defNamed(await loadOrNull(forkId), 'Breakfast').completed,
      isTrue,
      reason: 'the mark is on the copy',
    );
    expect(
      defNamed(await store.loadTree(routine.id), 'Breakfast').completed,
      isFalse,
      reason: 'never on the placeholder',
    );
    expect(
      (await store.timersInBoard(dayController.board.id))
          .where((t) => t.dayDate == dayNumber(tomorrow)),
      hasLength(1),
      reason: 'one copy per day — exactly once',
    );

    // 3 — the ROUTINE is edited in the library (saveTree on the
    //     placeholder plan — the editor's commit path): Breakfast is
    //     renamed and a new item joins the plan.
    final source = await store.loadTree(routine.id);
    await store.saveTree(
      routine.id,
      IntervalTree([
        ...source.updated('r1', (d) => d.copyWith(name: 'Big breakfast'))
            .roots,
        DefNode(
          IntervalDef(
            id: 'r3',
            timerId: routine.id,
            name: 'Lunch',
            color: '#0055ff',
            durationSeconds: 300,
            autoFinish: true,
          ),
        ),
      ]),
      eventKind: 'plan.edit',
    );

    // 4 — the day AFTER tomorrow: press the next-day chevron on
    //     tomorrow's board. Its PLACEHOLDER picked the edit up BY
    //     ARRIVAL — renamed row, new row, source ids — and still has no
    //     days row of its own, while tomorrow's copy stays FROZEN.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('day-gutter-right'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('day-next')));
    await settle(tester);

    expect(
      find.text('Big breakfast'),
      findsOneWidget,
      reason: 'the day after resolves the EDITED routine',
    );
    expect(
      find.byKey(const Key('row-r3')),
      findsOneWidget,
      reason: 'the new item arrived by placeholder read-through',
    );
    expect(
      find.byKey(const Key('row-r1')),
      findsOneWidget,
      reason: 'it is the SOURCE plan\u2019s ids — a placeholder, not a fork',
    );
    expect(await store.dayPlanId(dayAfter), isNull);
    expect(await materializationsOf(dayAfter), 0, reason: 'a read never forks');
    expect(await materializationsOf(tomorrow), 1, reason: 'still exactly once');

    // Tomorrow's fork is FROZEN: original names, the mark intact, and
    // still the day controller's timer.
    expect(
      names(await loadOrNull(forkId)),
      ['Breakfast', 'Stretch'],
      reason: 'a materialized day never tracks the library again',
    );
    expect(
      defNamed(await loadOrNull(forkId), 'Breakfast').completed,
      isTrue,
      reason: 'the mark survived on the frozen copy',
    );
    expect(dayController.timer.id, forkId);

    // 5 — yesterday's fork is untouched: same id, same frozen tree.
    expect(await store.dayPlanId(yesterday), yesterdayFork);
    expect(
      describeTree(await loadOrNull(yesterdayFork)),
      yesterdayFrozen,
      reason: 'a lived day never sees the library edit',
    );

    // Unwind: back to tomorrow's board (the chevron push disposes its
    // controller with the pop).
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('plan-bar')),
        matching: find.byKey(const Key('bar-back')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('plan-bar')), findsOneWidget);
    expect(dayController.timer.id, forkId);

    dayController.dispose();
    await store.close();
  });
}

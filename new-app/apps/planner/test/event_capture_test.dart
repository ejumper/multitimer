import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/day_navigation.dart';
import 'package:planner/editor_screen.dart';
import 'package:planner/event_capture.dart';
import 'package:planner/interval_editor.dart';
import 'package:planner/interval_rows.dart';
import 'package:planner/keyboard_nav.dart';
import 'package:planner/settings_service.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// P5.1 NEW EVENT quick capture — the pinned widget tests:
///
/// * event-mode layout: Time seeded ON, the `dd mm yy` Date boxes between
///   the label and the toggles, Overwrite Default Timer FIRST and OFF
///   (P5.2 seeds it from the New events override setting — the seeded-ON
///   flow pins the same toggle);
/// * **Save** inserts the event at the TOP of the target day's plan and
///   closes; **Save & edit timer** additionally opens that day's board
///   with the timer editor focused on the new interval;
/// * Overwrite ON REPLACES the day's plan with a single-interval timer;
/// * the no-plan-yet fallback pins a single-event plan;
/// * the overlap matrix — contained / partial blocked, edge-touching
///   saved, Open-point blocked at its exact trigger then saved once the
///   time changes;
/// * past-due events save; a FUTURE day materializes exactly once and the
///   library placeholder is never written;
/// * bad date boxes are refused (live hint + reason, nothing written).
///
/// Fixture: `Routine` (`r1 Breakfast 09:00–09:10`, `r2 Check-in` an Open
/// POINT at 10:00) claims TODAY and TOMORROW via one-off date rules —
/// every other day is unclaimed (the fallback's stage). The root board
/// boots on `Interval timer`. All dates derive from the clock through
/// [dayOf] — the same local-midnight form the boards speak.
///
/// The board's 1 Hz ticker hangs pumpAndSettle — every pump here is
/// bounded through [settle]; SnackBars are drained through [drainSnacks].
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late AppController controller;
  late IntervalTimer routine;

  /// Today on the clock — the day-key form the boards bind through.
  DateTime today() => dayOf(clock.now());

  Future<void> buildFixture() async {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);

    final board = await store.createBoard('My Board');
    // The boot plan: the root board binds the first plan, leaving
    // Routine to the day rules alone.
    final home = await store.createTimer(
      boardId: board.id,
      name: 'Interval timer',
      color: '#0055ff',
    );
    await store.saveTree(
      home.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'w1',
            timerId: home.id,
            name: 'Warmup',
            color: '#0055ff',
            durationSeconds: 60,
            autoFinish: false,
          ),
        ),
      ]),
      eventKind: 'tree.save',
    );

    routine = await store.createTimer(
      boardId: board.id,
      name: 'Routine',
      color: '#00ad6b',
    );
    await store.saveTree(
      routine.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'r1',
            timerId: routine.id,
            name: 'Breakfast',
            color: '#00ad6b',
            durationSeconds: 600, // 09:00–09:10
            autoFinish: false,
            triggerTimeSeconds: 32400,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'r2',
            timerId: routine.id,
            name: 'Check-in',
            color: '#00ad6b',
            durationSeconds: null, // Open — a POINT at 10:00
            autoFinish: false,
            triggerTimeSeconds: 36000,
          ),
        ),
      ]),
      eventKind: 'tree.save',
    );

    await store.addRule(
      timerId: routine.id,
      kind: DefaultRuleKind.date,
      value: dayNumber(today()),
    );
    await store.addRule(
      timerId: routine.id,
      kind: DefaultRuleKind.date,
      value: dayNumber(addDays(today(), 1)),
    );

    controller = AppController(
      store: store,
      clock: clock,
      notifier: RecordingNotifier(),
      player: RecordingPlayer(),
      soundsDir: '/sounds',
      soundListing: () => const [],
    );
    await controller.init();
  }

  setUp(buildFixture);

  /// Bounded settle — the ticker/pulse hang pumpAndSettle. Rounds of
  /// `pump()` + 300ms cover route transitions (150ms), the SnackBar in,
  /// and the store's async chains between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// Drain the SnackBar's 4s display timer + dismiss animation so a
  /// blocked-attempt test ends with no pending timer.
  Future<void> drainSnacks(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// The fixture's root board (main bar) on a surface tall enough for the
  /// whole event-mode editor — same accommodation as the editor tests.
  Future<void> pumpRootBoard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: BoardScreen(controller)));
    await tester.pump();
  }

  /// The main bar's New Event → the interval editor in EVENT MODE.
  Future<void> openCapture(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('bar-new-event')));
    await settle(tester);
    expect(find.byType(IntervalEditorScreen), findsOneWidget);
  }

  /// Type the target date into the `dd mm yy` boxes.
  Future<void> setDate(WidgetTester tester, DateTime date) async {
    await tester.enterText(
      find.byKey(const Key('ie-date-dd')),
      date.day.toString().padLeft(2, '0'),
    );
    await tester.enterText(
      find.byKey(const Key('ie-date-mm')),
      date.month.toString().padLeft(2, '0'),
    );
    await tester.enterText(
      find.byKey(const Key('ie-date-yy')),
      (date.year % 100).toString().padLeft(2, '0'),
    );
  }

  /// Tap a commit button (scrolled into view first — belt and braces).
  Future<void> tapCommit(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  /// [date]'s plan id — null while nothing claims it (or while a capture
  /// is still only refused).
  Future<String?> planIdOf(DateTime date) => store.dayPlanId(date);

  /// The plan's def names in tree order (the fixture has no groups).
  List<String> names(IntervalTree tree) => [
    for (final n in tree.allNodes.whereType<DefNode>()) n.def.name ?? '',
  ];

  /// How many times [date] materialized — `day.materialize` payloads carry
  /// the day number, so each day counts alone.
  Future<int> materializationsOf(DateTime date) async =>
      (await store.events())
          .where(
            (e) =>
                e.kind == 'day.materialize' &&
                (jsonDecode(e.payloadJson) as Map)['date'] ==
                    dayNumber(date),
          )
          .length;

  /// The fixture's library plan as it must NEVER change: two untouched
  /// defs, no captured event anywhere near it.
  Future<void> expectLibraryUntouched() async {
    expect(names(await store.loadTree(routine.id)), [
      'Breakfast',
      'Check-in',
    ]);
  }

  // ── event-mode layout ─────────────────────────────────────────────────

  testWidgets('event_mode_layout_time_on_date_boxes_overwrite_off', (
    tester,
  ) async {
    await pumpRootBoard(tester);
    await openCapture(tester);

    // Time seeded ON — the 24-hour wall setter shows at once.
    expect(
      tester.widget<Switch>(find.byKey(const Key('ie-time-toggle'))).value,
      isTrue,
    );
    expect(find.byKey(const Key('ie-time-hh')), findsOneWidget);

    // The Date boxes sit BETWEEN the label field and the option toggles …
    double yOf(Finder f) => tester.getTopLeft(f).dy;
    expect(
      yOf(find.byKey(const Key('ie-label'))),
      lessThan(yOf(find.byKey(const Key('ie-date-dd')))),
      reason: 'Date below the title field',
    );
    expect(
      yOf(find.byKey(const Key('ie-date-dd'))),
      lessThan(yOf(find.byKey(const Key('ie-overwrite')))),
      reason: 'Date above the toggles',
    );
    // … and Overwrite Default Timer is the FIRST option toggle.
    expect(
      yOf(find.byKey(const Key('ie-overwrite'))),
      lessThan(yOf(find.byKey(const Key('ie-autofinish')))),
      reason: 'Overwrite first, before Auto-finish',
    );

    // The Overwrite default is OFF (P5.2's setting seeds this seam).
    expect(
      tester.widget<Switch>(find.byKey(const Key('ie-overwrite'))).value,
      isFalse,
    );

    // The boxes are seeded with today (2026-03-01) …
    TextField boxOf(String key) =>
        tester.widget<TextField>(find.byKey(Key(key)));
    expect(boxOf('ie-date-dd').controller!.text, '01');
    expect(boxOf('ie-date-mm').controller!.text, '03');
    expect(boxOf('ie-date-yy').controller!.text, '26');
    // … and both commit buttons replace the plain commit.
    expect(find.byKey(const Key('ie-save')), findsOneWidget);
    expect(find.byKey(const Key('ie-save-edit')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // ── P5.2: the Overwrite toggle's settings seed ──────────────────────────

  testWidgets('overwrite_toggle_seeds_from_the_settings', (tester) async {
    // The New events override default ON — the capture must open with
    // its first option toggle already flipped …
    await store.setSetting(kSettingEventOverridesDefault, '1');
    await pumpRootBoard(tester);
    await openCapture(tester); // settle rounds — the seed lands

    expect(
      tester.widget<Switch>(find.byKey(const Key('ie-overwrite'))).value,
      isTrue,
      reason: 'the setting seeds the capture\u2019s Overwrite toggle',
    );

    // … and it DRIVES the save: Overwrite ON replaces the day’s plan
    // with the new single-interval timer.
    await tester.enterText(find.byKey(const Key('ie-label')), 'Dentist');
    await tapCommit(tester, 'ie-save');

    expect(find.byType(IntervalEditorScreen), findsNothing, reason: 'closed');
    final planId = await planIdOf(today());
    expect(planId, isNotNull);
    final tree = await store.loadTree(planId!);
    expect(
      [for (final n in tree.roots) (n as DefNode).def.name],
      ['Dentist'],
      reason: 'overwrite ON replaced the day plan with just the event',
    );
    await expectLibraryUntouched();

    controller.dispose();
    await store.close();
  });

  // ── Save / Save & edit timer ──────────────────────────────────────────

  testWidgets('save_inserts_event_at_top_of_day_plan_and_closes', (
    tester,
  ) async {
    await pumpRootBoard(tester);
    await openCapture(tester);
    await tester.enterText(find.byKey(const Key('ie-label')), 'Dentist');
    await tapCommit(tester, 'ie-save');

    expect(find.byType(IntervalEditorScreen), findsNothing, reason: 'closed');

    final planId = await planIdOf(today());
    expect(planId, isNotNull, reason: "the day's first write materializes it");
    final tree = await store.loadTree(planId!);
    expect(
      [for (final n in tree.roots) (n as DefNode).def.name],
      ['Dentist', 'Breakfast', 'Check-in'],
      reason: 'top-insertion — the event is the FIRST interval',
    );
    final first = (tree.roots.first as DefNode).def;
    expect(first.triggerTimeSeconds, 0); // the seeded 00:00 boxes
    expect(first.timerId, planId, reason: 'owned by the day plan');

    // The write landed on the day's copy — never the library placeholder.
    await expectLibraryUntouched();

    controller.dispose();
    await store.close();
  });

  testWidgets('save_and_edit_opens_day_board_with_editor_focused', (
    tester,
  ) async {
    await pumpRootBoard(tester);
    await openCapture(tester);
    await tester.enterText(find.byKey(const Key('ie-label')), 'Dentist');
    await tapCommit(tester, 'ie-save-edit');

    // The capture editor closed; the day board pushed underneath a timer
    // editor …
    expect(find.byType(IntervalEditorScreen), findsNothing);
    expect(find.byType(EditorScreen), findsOneWidget);
    expect(
      find.byKey(const Key('plan-bar'), skipOffstage: false),
      findsOneWidget,
      reason: "that day's board sits underneath the editor",
    );
    expect(find.byKey(const Key('main-bar')), findsNothing);

    // … holding the new interval, first in the day's plan.
    final planId = (await planIdOf(today()))!;
    final tree = await store.loadTree(planId);
    final defId = tree.roots.first.id;
    expect((tree.roots.first as DefNode).def.name, 'Dentist');
    expect(
      // Scoped to the BOARD: the editor on top shares the row keys.
      find.descendant(
        of: find.byType(BoardScreen, skipOffstage: false),
        matching: find.byKey(Key('row-$defId'), skipOffstage: false),
      ),
      findsOneWidget,
      reason: 'the day board renders the captured interval',
    );
    expect(find.byKey(Key('chip-$defId')), findsOneWidget);

    // FOCUSED on it: the row cell owns the keyboard ring …
    expect(
      find.descendant(
        of: find.byKey(Key('chip-$defId')),
        matching: find.byWidgetPredicate(
          (w) => w is FocusRing && w.focused,
          description: 'focused ring',
        ),
      ),
      findsOneWidget,
      reason: 'keyboard focus lands on the new interval',
    );
    // … and the row joined the selection.
    expect(
      tester.widget<RowCircle>(find.byKey(Key('select-$defId'))).checked,
      isTrue,
      reason: 'the new interval is selected',
    );

    // Unwind: close the editor, back off the day board → the root again.
    await tester.tap(find.byKey(const Key('editor-close')));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('plan-bar')),
        matching: find.byKey(const Key('bar-back')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('main-bar')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // ── Overwrite Default Timer / the no-plan fallback ────────────────────

  testWidgets('overwrite_on_replaces_day_plan_with_single_interval_timer', (
    tester,
  ) async {
    await pumpRootBoard(tester);
    await openCapture(tester);
    await tester.enterText(find.byKey(const Key('ie-label')), 'Dentist');
    await tester.enterText(find.byKey(const Key('ie-time-hh')), '15');
    await tester.enterText(find.byKey(const Key('ie-time-mm')), '00');
    await tester.tap(find.byKey(const Key('ie-overwrite')));
    await tester.pump();
    expect(
      tester.widget<Switch>(find.byKey(const Key('ie-overwrite'))).value,
      isTrue,
    );
    await tapCommit(tester, 'ie-save');

    expect(find.byType(IntervalEditorScreen), findsNothing);
    final planId = await planIdOf(today());
    expect(planId, isNotNull);
    expect(planId, isNot(routine.id), reason: 'a NEW timer takes the day');

    final tree = await store.loadTree(planId!);
    expect(tree.roots, hasLength(1), reason: 'a single-interval timer');
    final def = (tree.roots.single as DefNode).def;
    expect(def.name, 'Dentist');
    expect(def.triggerTimeSeconds, 54000); // 15:00
    expect(def.timerId, planId);

    // The replaced default is untouched — and overwrite never forks it
    // (the plan is replaced, not materialized).
    await expectLibraryUntouched();
    expect(await materializationsOf(today()), 0);

    controller.dispose();
    await store.close();
  });

  testWidgets('no_plan_day_fallback_creates_single_event_plan', (
    tester,
  ) async {
    final day3 = addDays(today(), 3); // nothing claims it — no rules
    await pumpRootBoard(tester);
    await openCapture(tester);
    await setDate(tester, day3);
    await tester.enterText(find.byKey(const Key('ie-label')), 'Dentist');
    await tapCommit(tester, 'ie-save');

    expect(find.byType(IntervalEditorScreen), findsNothing);
    final planId = await planIdOf(day3);
    expect(planId, isNotNull, reason: 'the fallback pins a fresh plan');
    expect(
      await materializationsOf(day3),
      0,
      reason: 'nothing claimed the day — there was no plan to fork',
    );

    final tree = await store.loadTree(planId!);
    expect(tree.roots, hasLength(1), reason: 'the single event IS the plan');
    final def = (tree.roots.single as DefNode).def;
    expect(def.name, 'Dentist');
    expect(def.timerId, planId);
    expect(
      (await store.timersInBoard(controller.board.id))
          .where((t) => t.id == planId),
      hasLength(1),
      reason: 'the fallback lands on the capture board',
    );
    await expectLibraryUntouched();

    controller.dispose();
    await store.close();
  });

  // ── the overlap matrix ────────────────────────────────────────────────

  const containedReason =
      'That time is taken — an event runs 09:00–09:10. Pick a different time.';
  const pointReason =
      'That time is taken — an event is set for 10:00. Pick a different time.';

  /// Opens a capture, fills [label] + [hh]:[mm] (and the duration when
  /// given) and taps Save — blocked or saved, the caller asserts which.
  Future<void> captureAt(
    WidgetTester tester, {
    required String label,
    required String hh,
    required String mm,
    String? durMin,
  }) async {
    await openCapture(tester);
    await tester.enterText(find.byKey(const Key('ie-label')), label);
    await tester.enterText(find.byKey(const Key('ie-time-hh')), hh);
    await tester.enterText(find.byKey(const Key('ie-time-mm')), mm);
    if (durMin != null) {
      await tester.enterText(find.byKey(const Key('ie-min')), durMin);
    }
    await tapCommit(tester, 'ie-save');
  }

  testWidgets('overlap_contained_window_is_blocked', (tester) async {
    await pumpRootBoard(tester);
    // 09:02 + the 60s default sits INSIDE Breakfast's 09:00–09:10.
    await captureAt(tester, label: 'Dentist', hh: '09', mm: '02');

    expect(find.text(containedReason), findsOneWidget);
    expect(
      find.byType(IntervalEditorScreen),
      findsOneWidget,
      reason: 'refused — the editor stays open until the time changes',
    );
    expect(
      await planIdOf(today()),
      isNull,
      reason: 'a refused capture writes nothing — not even a fork',
    );
    expect(
      (await store.events()).where((e) => e.kind == 'event.capture'),
      isEmpty,
    );

    await drainSnacks(tester);
    controller.dispose();
    await store.close();
  });

  testWidgets('overlap_partial_window_is_blocked', (tester) async {
    await pumpRootBoard(tester);
    // 08:55 for 10m = 08:55–09:05 — straddles Breakfast's start.
    await captureAt(
      tester,
      label: 'Dentist',
      hh: '08',
      mm: '55',
      durMin: '10',
    );

    expect(find.text(containedReason), findsOneWidget);
    expect(find.byType(IntervalEditorScreen), findsOneWidget);
    expect(await planIdOf(today()), isNull);
    expect(
      (await store.events()).where((e) => e.kind == 'event.capture'),
      isEmpty,
    );

    await drainSnacks(tester);
    controller.dispose();
    await store.close();
  });

  testWidgets('overlap_edge_touching_is_saved', (tester) async {
    await pumpRootBoard(tester);

    // (a) STARTS exactly where Breakfast ends (09:10) — not a conflict.
    await captureAt(
      tester,
      label: 'Edge start',
      hh: '09',
      mm: '10',
      durMin: '05',
    );
    expect(find.byType(IntervalEditorScreen), findsNothing, reason: 'saved');
    final planId = (await planIdOf(today()))!;
    expect(
      [for (final n in (await store.loadTree(planId)).roots)
        (n as DefNode).def.name],
      ['Edge start', 'Breakfast', 'Check-in'],
    );

    // (b) ENDS exactly where Breakfast begins (09:00) — not a conflict
    // either, even against the now-materialized plan.
    await captureAt(
      tester,
      label: 'Edge end',
      hh: '08',
      mm: '55',
      durMin: '05',
    );
    expect(find.byType(IntervalEditorScreen), findsNothing, reason: 'saved');
    expect(
      [for (final n in (await store.loadTree(planId)).roots)
        (n as DefNode).def.name],
      ['Edge end', 'Edge start', 'Breakfast', 'Check-in'],
    );

    controller.dispose();
    await store.close();
  });

  testWidgets('overlap_open_point_blocked_at_exact_trigger_then_saved', (
    tester,
  ) async {
    await pumpRootBoard(tester);

    // An Open event (Duration OFF) at Check-in's exact 10:00 trigger —
    // point-vs-point conflicts.
    await openCapture(tester);
    await tester.enterText(find.byKey(const Key('ie-label')), 'Check');
    await tester.tap(find.byKey(const Key('ie-duration-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('ie-hr')), findsNothing, reason: 'Open');
    await tester.enterText(find.byKey(const Key('ie-time-hh')), '10');
    await tester.enterText(find.byKey(const Key('ie-time-mm')), '00');
    await tapCommit(tester, 'ie-save');

    expect(find.text(pointReason), findsOneWidget);
    expect(find.byType(IntervalEditorScreen), findsOneWidget);
    expect(await planIdOf(today()), isNull);
    await drainSnacks(tester);

    // Move off the trigger — the same event saves as a point.
    await tester.enterText(find.byKey(const Key('ie-time-mm')), '30');
    await tapCommit(tester, 'ie-save');

    expect(find.byType(IntervalEditorScreen), findsNothing, reason: 'saved');
    final planId = (await planIdOf(today()))!;
    final def = (await store.loadTree(planId)).roots.first;
    final captured = (def as DefNode).def;
    expect(captured.name, 'Check');
    expect(captured.durationSeconds, isNull, reason: 'stays Open');
    expect(captured.triggerTimeSeconds, 37800); // 10:30

    controller.dispose();
    await store.close();
  });

  // ── past-due + future-day capture ─────────────────────────────────────

  testWidgets('past_due_event_saves', (tester) async {
    await pumpRootBoard(tester);
    // 03:00 sits BEFORE the clock's 08:00 — past-due events save fine
    // (the engine's late badge / run-start firing owns the rest, P1.4).
    await captureAt(tester, label: 'Early read', hh: '03', mm: '00');

    expect(find.byType(IntervalEditorScreen), findsNothing, reason: 'saved');
    final planId = (await planIdOf(today()))!;
    final first = (await store.loadTree(planId)).roots.first;
    final captured = (first as DefNode).def;
    expect(captured.name, 'Early read');
    expect(captured.triggerTimeSeconds, 10800); // 03:00
    expect(
      captured.triggerTimeSeconds! < clock.now().hour * 3600,
      isTrue,
      reason: 'genuinely past-due on this clock',
    );

    controller.dispose();
    await store.close();
  });

  testWidgets('future_day_capture_materializes_once_never_touches_library', (
    tester,
  ) async {
    final tomorrow = addDays(today(), 1); // claimed by the one-off rule
    await pumpRootBoard(tester);

    // First capture, retargeted to the FUTURE day through the date boxes.
    await openCapture(tester);
    await setDate(tester, tomorrow);
    await tester.enterText(find.byKey(const Key('ie-label')), 'Dentist');
    await tester.enterText(find.byKey(const Key('ie-time-hh')), '15');
    await tester.enterText(find.byKey(const Key('ie-time-mm')), '00');
    await tapCommit(tester, 'ie-save');

    expect(find.byType(IntervalEditorScreen), findsNothing, reason: 'saved');
    expect(
      await materializationsOf(tomorrow),
      1,
      reason: 'the future day materialized — the capture is its first write',
    );
    final forkId = (await planIdOf(tomorrow))!;
    expect(forkId, isNot(routine.id), reason: 'a day copy, not the plan');
    expect(names(await store.loadTree(forkId)), [
      'Dentist',
      'Breakfast',
      'Check-in',
    ]);

    // The library placeholder was never written …
    await expectLibraryUntouched();

    // … and a SECOND capture on the same day reuses the copy: still
    // exactly one materialization, still the same plan, event on top.
    await openCapture(tester);
    await setDate(tester, tomorrow);
    await tester.enterText(find.byKey(const Key('ie-label')), 'Coffee');
    await tester.enterText(find.byKey(const Key('ie-time-hh')), '16');
    await tester.enterText(find.byKey(const Key('ie-time-mm')), '00');
    await tapCommit(tester, 'ie-save');

    expect(find.byType(IntervalEditorScreen), findsNothing, reason: 'saved');
    expect(
      await materializationsOf(tomorrow),
      1,
      reason: 'materialized exactly once across every capture',
    );
    expect(await planIdOf(tomorrow), forkId, reason: 'no re-fork');
    expect(names(await store.loadTree(forkId)), [
      'Coffee',
      'Dentist',
      'Breakfast',
      'Check-in',
    ]);
    await expectLibraryUntouched();

    controller.dispose();
    await store.close();
  });

  // ── date-box validation ───────────────────────────────────────────────

  testWidgets('invalid_date_boxes_are_rejected', (tester) async {
    await pumpRootBoard(tester);
    await openCapture(tester);

    // 31 February is not a real day — the live hint says so at once …
    await tester.enterText(find.byKey(const Key('ie-date-dd')), '31');
    await tester.enterText(find.byKey(const Key('ie-date-mm')), '02');
    await tester.enterText(find.byKey(const Key('ie-date-yy')), '26');
    await tester.pump();
    expect(find.text('invalid date'), findsOneWidget);

    // … and Save refuses with the reason, writing NOTHING.
    await tapCommit(tester, 'ie-save');
    expect(find.text(kEventBadDateReason), findsOneWidget);
    expect(find.byType(IntervalEditorScreen), findsOneWidget);
    expect(await planIdOf(today()), isNull);
    await drainSnacks(tester);

    // Corrected to today (01 Mar 26) the capture lands normally.
    await setDate(tester, today());
    await tapCommit(tester, 'ie-save');
    expect(find.byType(IntervalEditorScreen), findsNothing, reason: 'saved');
    expect(await planIdOf(today()), isNotNull);

    controller.dispose();
    await store.close();
  });

  // ── the pure seams (date parsing + window math) ───────────────────────

  test('parse_event_date_rejects_impossible_days', () {
    expect(parseEventDate('01', '03', '26'), DateTime(2026, 3, 1));
    expect(parseEventDate('1', '5', '26'), DateTime(2026, 5, 1)); // unpadded
    expect(parseEventDate('29', '02', '24'), DateTime(2024, 2, 29)); // leap
    expect(parseEventDate('31', '02', '26'), isNull); // rolls into March
    expect(parseEventDate('29', '02', '26'), isNull);
    expect(parseEventDate('00', '03', '26'), isNull);
    expect(parseEventDate('15', '13', '26'), isNull);
    expect(parseEventDate('', '03', '26'), isNull);
    expect(parseEventDate('ab', '03', '26'), isNull);
  });

  test('event_overlap_reason_matrix', () {
    IntervalDef cand({int? trigger, int? duration}) => IntervalDef(
      id: 'c',
      timerId: 't',
      color: '#0055ff',
      autoFinish: false,
      durationSeconds: duration,
      triggerTimeSeconds: trigger,
    );

    final plan = IntervalTree([
      DefNode(cand(trigger: 32400, duration: 600)), // 09:00–09:10
      DefNode(cand(trigger: 36000, duration: null)), // point 10:00
    ]);

    // Contained / partial windows are refused …
    expect(eventOverlapReason(plan, cand(trigger: 32520, duration: 60)), isNotNull);
    expect(eventOverlapReason(plan, cand(trigger: 32100, duration: 600)), isNotNull);
    // … edge-touching is NOT a conflict, either direction …
    expect(eventOverlapReason(plan, cand(trigger: 33000, duration: 300)), isNull);
    expect(eventOverlapReason(plan, cand(trigger: 32100, duration: 300)), isNull);
    // … an Open point conflicts only at its exact trigger (or inside a
    // window) …
    expect(eventOverlapReason(plan, cand(trigger: 36000, duration: null)), isNotNull);
    expect(eventOverlapReason(plan, cand(trigger: 32700, duration: null)), isNotNull);
    expect(eventOverlapReason(plan, cand(trigger: 36001, duration: null)), isNull);
    // … and an order-triggered candidate has no wall to collide with.
    expect(eventOverlapReason(plan, cand(trigger: null, duration: 60)), isNull);
  });

  // P5.1 review fix: a capture-created day plan is DAY-OWNED from birth —
  // it lives under its day (never in the Library) and the lazy fork finds
  // it instead of forking it a second time.
  testWidgets('capture_fresh_plan_is_day_owned_and_never_re_forked', (
    tester,
  ) async {
    // Overwrite ON on an UNCLAIMED day -> the fallback fresh plan.
    await pumpRootBoard(tester);
    await openCapture(tester);
    await tester.enterText(find.byKey(const Key('ie-label')), 'Dentist');
    await tester.tap(find.byKey(const Key('ie-overwrite')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('ie-save')));
    await settle(tester);

    final planId = (await planIdOf(today()))!;
    final all = await store.timersInBoard(controller.board.id);
    final plan = all.firstWhere((t) => t.id == planId);
    expect(plan.dayDate, dayNumber(today()), reason: 'day-owned from birth');

    // A later write on that day must NOT fork it again.
    await store.materializeDay(today());
    await store.materializeDay(today());
    final owns = [
      for (final t in await store.timersInBoard(controller.board.id))
        if (t.dayDate == dayNumber(today())) t,
    ];
    expect(owns, hasLength(1), reason: 'materializes exactly once');
  });

}

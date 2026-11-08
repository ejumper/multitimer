import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/bottom_bar.dart';
import 'package:planner/day_navigation.dart';
import 'package:planner/interval_rows.dart';
import 'package:planner/theme.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Day-board widget tests (v2 P4.3): the board bound to a date.
///
/// Pinned here: the hover-revealed edge chevrons render ONLY on
/// date-bound boards (the board root and a plain Library plan board have
/// none) and stay hidden until their gutter is hovered · the chevrons
/// step to the PREVIOUS and NEXT day (each push makes back walk the
/// days), reading through without ever materializing · placeholder/fork
/// render parity: a day board renders IDENTICALLY before and after the
/// check that materializes it — same rows, same state, same keys across
/// forked renders — so the user cannot tell which one they are looking
/// at.
///
/// Fixture (saved BEFORE init): `Routine` (`r1 Breakfast 600s`,
/// `r2 Stretch` Open — mixed → chain mode) claiming EVERY day via a
/// GLOBAL DEFAULT, plus `Errands` (3 Open) claiming YESTERDAY and
/// `Chores` (2 Open) claiming TOMORROW via one-off `date` rules — so a
/// chevron step is visible in the rows. Rules only — no `setDayPlan`
/// pins, so any `days` row would be a materialization.
///
/// All test dates derive from the clock through [dayOf] — the SAME
/// local-midnight form `init(dayDate:)` and [homeDayDate] speak.
///
/// The board's 1 Hz ticker hangs pumpAndSettle — every pump here is
/// bounded through [settle] (`tester.pump()` [+ 300ms] rounds).
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late AppController controller;
  late IntervalTimer routine;
  late IntervalTimer errands;
  late IntervalTimer chores;

  /// Today on the clock — the day-key form the boards bind through.
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

    errands = await store.createTimer(
      boardId: board.id,
      name: 'Errands',
      color: '#00ad6b',
    );
    await store.saveTree(
      errands.id,
      IntervalTree([
        for (final (id, name) in [
          ('e1', 'Post'),
          ('e2', 'Groceries'),
          ('e3', 'Returns'),
        ])
          DefNode(
            IntervalDef(
              id: id,
              timerId: errands.id,
              name: name,
              color: '#00ad6b',
              durationSeconds: null, // Open
              autoFinish: false,
            ),
          ),
      ]),
      eventKind: 'tree.save',
    );

    chores = await store.createTimer(
      boardId: board.id,
      name: 'Chores',
      color: '#ff00b1',
    );
    await store.saveTree(
      chores.id,
      IntervalTree([
        for (final (id, name) in [('c1', 'Dishes'), ('c2', 'Sweep')])
          DefNode(
            IntervalDef(
              id: id,
              timerId: chores.id,
              name: name,
              color: '#ff00b1',
              durationSeconds: null, // Open
              autoFinish: false,
            ),
          ),
      ]),
      eventKind: 'tree.save',
    );

    // Routine claims every day; the chevron step's neighbours differ so
    // a navigation is visible in the rows: YESTERDAY → Errands,
    // TOMORROW → Chores (one-off date rules beat the global default).
    await store.addRule(
      timerId: routine.id,
      kind: DefaultRuleKind.globalDefault,
    );
    await store.addRule(
      timerId: errands.id,
      kind: DefaultRuleKind.date,
      value: dayNumber(addDays(today(), -1)),
    );
    await store.addRule(
      timerId: chores.id,
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
  /// `pump()` + 300ms cover route transitions (150ms), the chevron
  /// reveal, and the store's async chains between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// The fixture's board root (main bar) as the app's root route.
  Future<void> pumpRootBoard(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: BoardScreen(controller)));
    await tester.pump();
  }

  /// A second controller for [date]'s board — the tests own these, so
  /// every one is disposed by the test that asked for it.
  AppController makeController() => AppController(
    store: store,
    clock: clock,
    notifier: RecordingNotifier(),
    player: RecordingPlayer(),
    soundsDir: '/sounds',
    soundListing: () => const [],
  );

  /// [date]'s day board as the ROOT route — these tests address the
  /// board itself (the calendar's day-row open is pinned in
  /// calendar_screen_test). The caller disposes the returned controller.
  Future<AppController> pumpDayBoard(WidgetTester tester, DateTime date) async {
    final day = makeController();
    await day.init(dayDate: date);
    await tester.pumpWidget(
      MaterialApp(home: BoardScreen(day, bar: BoardBar.plan)),
    );
    await tester.pump();
    return day;
  }

  /// Every board row: an Opacity keyed `row-<def id>` (the value-keyed
  /// widget inside the row's GlobalKey wrapper).
  Finder boardRows() => find.byWidgetPredicate(
    (w) =>
        w is Opacity &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('row-'),
    description: 'board row',
  );

  /// The board's row keys' def ids, in tree order (rows are a plain
  /// Column — traversal order IS the visual order).
  List<String> rowIds(WidgetTester tester) => [
    for (final w in tester.widgetList<Opacity>(boardRows()))
      (w.key! as ValueKey<String>).value.substring('row-'.length),
  ];

  /// Every row's texts, in order (the chip's name, shape, alert label).
  List<String?> rowTexts(WidgetTester tester, String id) => [
    for (final t in tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(Key('row-$id')),
        matching: find.byType(Text),
      ),
    ))
      t.data,
  ];

  /// The "Retry missed (n)" residue button's text — null when absent.
  /// It rides with the MARKS (only a checked-and-not-started board
  /// shows it), so [structure] deliberately leaves it out.
  String? retryText(WidgetTester tester) {
    final retry = find.byKey(const Key('btn-retry-missed'));
    if (retry.evaluate().isEmpty) return null;
    return tester.widget<Text>(
      find.descendant(of: retry, matching: find.byType(Text)),
    ).data;
  }

  /// The board's user-visible render, keyed by POSITION rather than by
  /// def id — a fork's ids are fresh by the engine's copy rule (P1.1),
  /// and the pin here is that the USER cannot tell the placeholder from
  /// the copy.
  Map<String, Object?> fingerprint(WidgetTester tester) {
    final readout = find.descendant(
      of: find.byKey(const Key('readout')),
      matching: find.byType(Text),
    );
    return {
      'readout': [for (final t in tester.widgetList<Text>(readout)) t.data],
      'readout-color': tester.widget<Text>(readout.first).style?.color,
      'rows': <Map<String, Object?>>[
        for (final id in rowIds(tester))
          {
            'texts': rowTexts(tester, id),
            'opacity': tester.widget<Opacity>(find.byKey(Key('row-$id'))).opacity,
            'checked': tester.widget<RowCircle>(
              find.byKey(Key('check-$id')),
            ).checked,
            'fill': tester.widget<RowFill>(find.byKey(Key('fill-$id'))).fraction,
          },
      ],
      'retry': retryText(tester),
      'control': [
        for (final w in tester.widgetList<IconButton>(
          find.descendant(
            of: find.byKey(const Key('control-row')),
            matching: find.byType(IconButton),
          ),
        ))
          w.key!,
      ],
      'bar': [
        for (final w in tester.widgetList<IconButton>(
          find.descendant(
            of: find.byKey(const Key('plan-bar')),
            matching: find.byType(IconButton),
          ),
        ))
          w.key!,
      ],
      'chevrons': [
        tester.widget<AnimatedOpacity>(
          find.byKey(const Key('day-prev-reveal')),
        ).opacity,
        tester.widget<AnimatedOpacity>(
          find.byKey(const Key('day-next-reveal')),
        ).opacity,
      ],
    };
  }

  /// What the fork could never change: rows (texts, shapes, fills),
  /// readout, controls, bar — everything except the marks themselves.
  Map<String, Object?> structure(Map<String, Object?> board) => {
    'readout': board['readout'],
    'readout-color': board['readout-color'],
    'rows': [
      for (final row in board['rows']! as List<Map<String, Object?>>)
        {'texts': row['texts'], 'fill': row['fill']},
    ],
    'control': board['control'],
    'bar': board['bar'],
  };

  List<Map<String, Object?>> rowsOf(Map<String, Object?> board) =>
      board['rows']! as List<Map<String, Object?>>;

  // ── P4.3: chevrons only on date-bound boards ───────────────────────────

  testWidgets('step_chevrons_render_only_on_date_bound_boards', (
    tester,
  ) async {
    // The board root (main bar): a plain, NON-date-bound board.
    await pumpRootBoard(tester);
    expect(find.byKey(const Key('day-gutter-left')), findsNothing);
    expect(find.byKey(const Key('day-gutter-right')), findsNothing);
    expect(find.byKey(const Key('day-prev')), findsNothing);
    expect(find.byKey(const Key('day-next')), findsNothing);

    // A Library plan board (plan bar, no date binding): none either.
    final plan = makeController();
    await plan.init(timerId: chores.id);
    await tester.pumpWidget(
      MaterialApp(home: BoardScreen(plan, bar: BoardBar.plan)),
    );
    await tester.pump();
    expect(find.byKey(const Key('day-gutter-left')), findsNothing);
    expect(find.byKey(const Key('day-prev')), findsNothing);

    // A DAY board: both gutters, hidden until their edge is hovered.
    final day = await pumpDayBoard(tester, today());
    plan.dispose(); // its tree is gone — safe to drop now
    expect(find.byKey(const Key('day-gutter-left')), findsOneWidget);
    expect(find.byKey(const Key('day-gutter-right')), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byKey(const Key('day-prev-reveal')))
          .opacity,
      0.0,
      reason: 'hidden at rest (the calendar reveal pattern)',
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byKey(const Key('day-next-reveal')))
          .opacity,
      0.0,
    );

    // Hovering the LEFT strip reveals ONLY the previous-day chevron …
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('day-gutter-left'))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<AnimatedOpacity>(find.byKey(const Key('day-prev-reveal')))
          .opacity,
      1.0,
    );
    expect(
      tester.widget<AnimatedOpacity>(find.byKey(const Key('day-next-reveal')))
          .opacity,
      0.0,
    );

    day.dispose();
    controller.dispose();
    await store.close();
  });

  // ── P4.3: the chevrons navigate (both directions) ──────────────────────

  testWidgets('step_chevrons_navigate_both_directions_back_walks_days', (
    tester,
  ) async {
    final day = await pumpDayBoard(tester, today());
    // TODAY resolves the global default: Routine's rows, read-only.
    expect(find.byKey(const Key('row-r1')), findsOneWidget);
    expect(await store.dayPlanId(today()), isNull, reason: 'open never forks');

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    // LEFT → the PREVIOUS day: the one-off rule claims it, so Errands'
    // rows replace Routine's — and nothing materializes.
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('day-gutter-left'))));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('day-prev')));
    await settle(tester);
    expect(find.byKey(const Key('row-e1')), findsOneWidget);
    expect(
      find.byKey(const Key('row-r1')),
      findsNothing,
      reason: 'the previous day is what pushed, not today',
    );
    expect(await store.dayPlanId(addDays(today(), -1)), isNull);

    // BACK walks the days: today's board was underneath and returns.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('plan-bar')),
        matching: find.byKey(const Key('bar-back')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('row-r1')), findsOneWidget);
    expect(find.byKey(const Key('row-e1')), findsNothing);

    // RIGHT → the NEXT day: Chores' one-off rule claims tomorrow.
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('day-gutter-right'))));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('day-next')));
    await settle(tester);
    expect(find.byKey(const Key('row-c1')), findsOneWidget);
    expect(find.byKey(const Key('row-r1')), findsNothing);
    expect(await store.dayPlanId(addDays(today(), 1)), isNull);

    // Everything above was reading through: zero forks, zero day rows.
    expect(
      (await store.events()).where((e) => e.kind == 'day.materialize'),
      isEmpty,
      reason: 'navigation never materializes',
    );
    expect(
      (await store.timersInBoard(controller.board.id))
          .where((t) => t.dayDate != null),
      isEmpty,
    );

    // Unwind: back to today (the pushed neighbor disposes with its
    // route — openDayBoard's await resolves on the pop).
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('plan-bar')),
        matching: find.byKey(const Key('bar-back')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('row-r1')), findsOneWidget);

    day.dispose();
    controller.dispose();
    await store.close();
  });

  // ── P4.3 rule 1: placeholder/fork render parity ────────────────────────

  testWidgets('day_board_renders_identically_before_and_after_the_fork', (
    tester,
  ) async {
    final date = addDays(today(), 3); // a plain global-default (Routine) day
    final day = await pumpDayBoard(tester, date);
    expect(await store.dayPlanId(date), isNull, reason: 'placeholder open');

    final placeholder = fingerprint(tester);
    expect(rowsOf(placeholder), hasLength(2));

    // The CHECK is the day's first write: materializes exactly once, the
    // mark lands on the copy, the board rebinds to it.
    await tester.tap(find.byKey(const Key('check-r1')));
    await settle(tester);
    final forkId = await store.dayPlanId(date);
    expect(forkId, isNotNull);
    expect(day.timer.id, forkId, reason: 'the board rebinds to its copy');
    expect(
      (await store.events()).where((e) => e.kind == 'day.materialize'),
      hasLength(1),
    );

    // STRUCTURAL parity across the fork: the copy swapped nothing the
    // user can see — same rows, texts, shapes, fills, readout, controls,
    // bar. Only the check's own marks differ (the row it dimmed).
    final forked = fingerprint(tester);
    expect(structure(forked), structure(placeholder));
    expect(rowsOf(forked)[0]['checked'], isTrue);
    expect(rowsOf(forked)[0]['opacity'], AppColors.dimmed.a);
    expect(
      rowsOf(forked)[1],
      rowsOf(placeholder)[1],
      reason: 'the untouched row is untouched by the fork',
    );

    // Un-check (still the same copy): the board is EXACTLY the
    // placeholder render again — the user cannot tell which they look at.
    final ids = rowIds(tester);
    await tester.tap(find.byKey(Key('check-${ids.first}')));
    await settle(tester);
    final restored = fingerprint(tester);
    expect(restored, placeholder, reason: 'placeholder ⇄ fork parity');
    expect(await store.dayPlanId(date), forkId);
    expect(
      (await store.events()).where((e) => e.kind == 'day.materialize'),
      hasLength(1),
      reason: 'exactly once across every write',
    );

    // Re-OPEN the day (a fresh controller binds the FORK from the
    // start): the render is the same one — row KEYS included (the copy
    // keeps its ids across opens).
    final reopened = makeController();
    await reopened.init(dayDate: date);
    await tester.pumpWidget(
      MaterialApp(home: BoardScreen(reopened, bar: BoardBar.plan)),
    );
    await settle(tester);
    day.dispose(); // its tree is gone — drop it before the end
    expect(fingerprint(tester), restored);
    expect(rowIds(tester), ids, reason: 'the copy keeps its ids across opens');

    reopened.dispose();
    controller.dispose();
    await store.close();
  });
}

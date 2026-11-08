import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/day_navigation.dart';
import 'package:planner/settings_service.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Home navigation widget tests (v2 P4.3, P5.2-completed): every
/// bottom-bar home button lands on the Home DEFINITION — TODAY'S day
/// board by default, the configured SPECIFIC PLAN's board when the P5.2
/// Home setting names one — with the plain pop-to-the-board-root as the
/// fallback when nothing claims today. ([homeDayDate] consults the
/// setting; the Settings page itself is pinned in settings_screen_test.)
///
/// Pinned here: home pressed on the LIBRARY and on a PLAN board pops the
/// stack to the root and pushes today's board — the claimed plan's rows,
/// a day board's gutters, still a read-through (`dayPlanId` stays null —
/// Home never materializes), back = the root · the FALLBACK: a fixture
/// with no rules (nothing claims today) keeps the pre-P4.3 pop-to-root
/// exactly (the Library's `plan_board_home_pops_to_the_board_root` pins
/// the plan-board press of the same branch). The CALENDAR and DAY-BOARD
/// press sites are pinned in calendar_screen_test.
///
/// Fixture: `Routine` (2 intervals) via a GLOBAL DEFAULT rule plus
/// `Errands` (3 Open) claiming TODAY via a one-off `date` rule — so
/// Home's target is tellable from any other board by its rows. The rule
/// and the expectation both derive from [dayOf(clock.now())] — the same
/// local-midnight day [openHome] resolves.
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

  /// Today on the clock — the day Home resolves and the rule claims.
  DateTime today() => dayOf(clock.now());

  /// [withRules] off = the unclaimed-today fallback fixture (the same
  /// shape the Library's fallback test rides).
  Future<void> buildFixture({bool withRules = true}) async {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);

    final board = await store.createBoard('My Board');

    // Created first: the boot board binds it (the root's rows).
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

    if (withRules) {
      await store.addRule(
        timerId: routine.id,
        kind: DefaultRuleKind.globalDefault,
      );
      // TODAY claims Errands — Home's target is tellable by its rows.
      await store.addRule(
        timerId: errands.id,
        kind: DefaultRuleKind.date,
        value: dayNumber(today()),
      );
    }

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

  /// Bounded settle — the ticker/pulse hang pumpAndSettle. Rounds of
  /// `pump()` + 300ms cover the route transitions (150ms), Home's
  /// resolve→pop→init→push chain, and the store's async reads.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpRootBoard(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: BoardScreen(controller)));
    await tester.pump();
  }

  Future<void> openLibrary(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('bar-library')));
    await settle(tester);
    expect(find.byKey(const Key('library-page')), findsOneWidget);
  }

  Future<void> pressHome(WidgetTester tester, Finder bar) async {
    await tester.tap(
      find.descendant(of: bar, matching: find.byKey(const Key('bar-home'))),
    );
    await settle(tester);
  }

  Future<void> pressBack(WidgetTester tester, Finder bar) async {
    await tester.tap(
      find.descendant(of: bar, matching: find.byKey(const Key('bar-back'))),
    );
    await settle(tester);
  }

  // ── P4.3: Home lands on today's day board ──────────────────────────────

  testWidgets('home_lands_on_todays_day_board_from_library_and_plan_board', (
    tester,
  ) async {
    await buildFixture(); // today → Errands (the date rule)
    final day0 = today();
    await pumpRootBoard(tester);

    // From the LIBRARY: the page pops with the stack's return to the
    // root, TODAY's board (Errands' rows, day-board gutters) lands on
    // top — read-only, nothing materialized.
    await openLibrary(tester);
    await pressHome(tester, find.byKey(const Key('library-bar')));
    expect(find.byKey(const Key('library-page')), findsNothing);
    expect(
      find.byKey(const Key('plan-bar')),
      findsOneWidget,
      reason: 'today\u2019s day board is what Home landed on',
    );
    expect(find.byKey(const Key('row-e1')), findsOneWidget);
    expect(
      find.byKey(const Key('day-gutter-left')),
      findsOneWidget,
      reason: 'it IS a day board',
    );
    expect(
      await store.dayPlanId(day0),
      isNull,
      reason: 'Home reads through — it never materializes today',
    );
    expect(
      find.byKey(const Key('main-bar'), skipOffstage: false),
      findsOneWidget,
      reason: 'the stack sits on the root with today\u2019s board over it',
    );

    // Back from Home = the board root (the pop happened before the push).
    await pressBack(tester, find.byKey(const Key('plan-bar')));
    expect(find.byKey(const Key('plan-bar')), findsNothing);
    expect(find.byKey(const Key('main-bar')), findsOneWidget);

    // From a PLAN board: same landing — the plan board AND the Library
    // go with the pop, and today's board (Errands' rows, not the plan's
    // Breakfast rows) is what shows.
    await openLibrary(tester);
    await tester.tap(find.byKey(Key('plan-${routine.id}')));
    await settle(tester);
    expect(find.byKey(const Key('row-r1')), findsOneWidget); // the plan board

    await pressHome(tester, find.byKey(const Key('plan-bar')));
    expect(find.byKey(const Key('library-page')), findsNothing);
    expect(find.byKey(const Key('plan-bar')), findsOneWidget);
    expect(
      find.byKey(const Key('row-e1')),
      findsOneWidget,
      reason: 'today\u2019s board, not the plan that pressed Home',
    );
    expect(
      find.byKey(const Key('row-r1')),
      findsNothing,
      reason: 'the plan board popped and the root is covered',
    );
    expect(await store.dayPlanId(day0), isNull, reason: 'still read-only');

    await pressBack(tester, find.byKey(const Key('plan-bar')));
    expect(find.byKey(const Key('main-bar')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // ── P4.3: the unclaimed-today fallback ─────────────────────────────────

  testWidgets('home_falls_back_to_the_board_root_when_nothing_claims_today', (
    tester,
  ) async {
    await buildFixture(withRules: false); // resolveDayPlan(today) → null
    await pumpRootBoard(tester);
    await openLibrary(tester);

    await pressHome(tester, find.byKey(const Key('library-bar')));

    // Exactly the pre-P4.3 behavior: pop to the root, no day board.
    expect(find.byKey(const Key('library-page')), findsNothing);
    expect(
      find.byKey(const Key('plan-bar')),
      findsNothing,
      reason: 'nothing claims today → no day board is pushed',
    );
    expect(find.byKey(const Key('day-gutter-left')), findsNothing);
    expect(find.byKey(const Key('main-bar')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // ── P5.2: Home = a specific plan ────────────────────────────────────────

  testWidgets('home_lands_on_the_configured_specific_plan_board', (
    tester,
  ) async {
    await buildFixture(); // today → Errands (the date rule)
    final day0 = today();
    // The Home setting names ROUTINE — tellable from Errands' rows AND
    // from the missing day-board gutters.
    await store.setSetting(kSettingHomePlanId, routine.id);
    await pumpRootBoard(tester);

    // The seam itself: today IS claimed by Errands, yet Home resolves
    // to no DAY board — the plan half of the setting owns the answer.
    expect(await store.resolveDayPlan(day0), errands.id);
    expect(await homeDayDate(store, day0), isNull);
    expect(await homePlanId(store), routine.id);

    await openLibrary(tester);
    await pressHome(tester, find.byKey(const Key('library-bar')));

    // The stack sits on the root with ROUTINE'S plan board over it: the
    // plan bar, the plan's own rows, and NO day-board gutters — a plan
    // home is not a day board.
    expect(find.byKey(const Key('library-page')), findsNothing);
    expect(find.byKey(const Key('plan-bar')), findsOneWidget);
    expect(find.byKey(const Key('row-r1')), findsOneWidget);
    expect(find.byKey(const Key('row-r2')), findsOneWidget);
    expect(
      find.byKey(const Key('day-gutter-left')),
      findsNothing,
      reason: 'the specific plan\u2019s board is an ordinary plan board',
    );
    expect(
      await store.dayPlanId(day0),
      isNull,
      reason: 'opening the plan home never materializes today',
    );

    // Back from Home = the board root (the pop happened before the push).
    await pressBack(tester, find.byKey(const Key('plan-bar')));
    expect(find.byKey(const Key('main-bar')), findsOneWidget);

    controller.dispose();
    await store.close();
  });
}

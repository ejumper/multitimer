import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/theme.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Calendar page widget tests (v2 P4.2): the outline's calendar view.
///
/// Pinned here: the main bar's Calendar button is ALIVE and pushes the
/// page (home returns) with its own bar (home · view toggle · date
/// setter) · WEEK rows = 7 days with `Monday … name + count` read
/// THROUGH the placeholder (no materialization: every shown day's
/// `dayPlanId` stays null and no fork timer exists) · MONTH rows = the
/// shown month's days, same row shape · today highlighted with the
/// theme's tokens vs the plain card rows · the date setter steps its
/// month-grid, picks, and lands the picked day's week with the row
/// highlighted · the edge chevrons hover-reveal and page week (±7 days)
/// and month (±1 month) both ways · the view toggle switches week ↔
/// month · tapping a day opens THAT DAY'S board through the `dayDate`
/// seam (read-only) and back/home return.
///
/// Fixture (saved BEFORE init): `Errands` (3 Open intervals, created
/// first so the boot board binds IT) and `Routine` (2 intervals, count
/// 2) claiming every day via a GLOBAL DEFAULT rule; the shown week's
/// Wednesday claims `Errands` instead via a one-off `date` rule
/// (count 3). Rules only — NO `setDayPlan` pins, so any `days` row would
/// be a materialization.
///
/// "Today" derives from [FixedClock]'s t0 through the same local-time
/// conversion the page uses ([today]) — expectations stay consistent
/// whatever the host timezone reads t0 as.
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

  const dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// The clock's instant as a LOCAL calendar day — the same conversion
  /// the Calendar page derives "today" with.
  DateTime today() {
    final now = DateTime.fromMillisecondsSinceEpoch(
      clock.now().millisecondsSinceEpoch,
    );
    return DateTime(now.year, now.month, now.day);
  }

  DateTime mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  /// [d]'s month moved by [delta], landing on its 1st (pure calendar
  /// arithmetic — no `Duration`, no month-0 reliance).
  DateTime monthStart(DateTime d, int delta) {
    final total = d.year * 12 + (d.month - 1) + delta;
    return DateTime(total ~/ 12, total % 12 + 1, 1);
  }

  int daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

  /// The local ISO day the row keys use (CONVENTIONS §7).
  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String monthLabel(DateTime m) => '${monthNames[m.month - 1]} ${m.year}';

  Future<void> buildFixture() async {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);

    final board = await store.createBoard('My Board');

    // Created FIRST: the boot controller binds IT, leaving routine's rows
    // to the day board alone (the open-day assertions address `row-r1`).
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

    // Rules only (never `setDayPlan`): Routine claims EVERY day (count 2),
    // and the shown week's Wednesday claims Errands via a one-off `date`
    // rule (count 3) — both counts are pure read-throughs.
    await store.addRule(
      timerId: routine.id,
      kind: DefaultRuleKind.globalDefault,
    );
    await store.addRule(
      timerId: errands.id,
      kind: DefaultRuleKind.date,
      value: dayNumber(addDays(mondayOf(today()), 2)),
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
  /// reveal, and the store's async count batches between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpBoard(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: BoardScreen(controller)));
    await tester.pump();
  }

  Future<void> openCalendar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('bar-calendar')));
    await settle(tester);
    expect(find.byKey(const Key('calendar-page')), findsOneWidget);
  }

  /// Every rendered day row (keyed `day-<iso>`), in tree order — the
  /// rows are never lazy (the board's list-view rule), so month view
  /// counts ALL of its days whatever the viewport shows.
  Finder dayRows() => find.byWidgetPredicate(
    (w) {
      final key = w.key;
      return w is GestureDetector &&
          key is ValueKey<String> &&
          key.value.startsWith('day-');
    },
    description: 'calendar day row',
  );

  /// The row's decorated background (its ONE Container child).
  BoxDecoration boxOf(WidgetTester tester, Finder row) {
    final box = tester.widget<Container>(
      find.descendant(of: row, matching: find.byType(Container)),
    );
    return box.decoration! as BoxDecoration;
  }

  // ── P4.2: the shell ────────────────────────────────────────────────────

  testWidgets('calendar_opens_from_the_main_bar_with_its_own_bar', (
    tester,
  ) async {
    await pumpBoard(tester);

    // The board's Calendar button is ALIVE now (P4.2) …
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('bar-calendar')))
          .onPressed,
      isNotNull,
    );
    await openCalendar(tester);

    // … and the page renders its own bar: home · view toggle · setter.
    expect(find.text('Calendar'), findsOneWidget);
    final buttons = find.descendant(
      of: find.byKey(const Key('calendar-bar')),
      matching: find.byType(IconButton),
    );
    expect(buttons, findsNWidgets(3));
    expect(
      [for (final w in tester.widgetList<IconButton>(buttons)) w.key!],
      const [Key('bar-home'), Key('bar-view-toggle'), Key('bar-date-setter')],
      reason: 'left→right: home · view toggle · date setter (P4.2 rule 5)',
    );

    // Home pops the Calendar — the board root is back.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('calendar-bar')),
        matching: find.byKey(const Key('bar-home')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('calendar-page')), findsNothing);
    expect(find.byKey(const Key('main-bar')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // ── P4.2 rule 1: the day rows ──────────────────────────────────────────

  testWidgets('week_rows_show_seven_days_with_read_through_counts', (
    tester,
  ) async {
    await pumpBoard(tester);
    await openCalendar(tester);

    expect(dayRows(), findsNWidgets(7));
    final day0 = today();
    final monday = mondayOf(day0);
    for (var i = 0; i < 7; i++) {
      final day = addDays(monday, i);
      final key = Key('day-${iso(day)}');
      expect(find.byKey(key), findsOneWidget, reason: 'week day ${iso(day)}');
      // The row vocabulary: day NAME … plain COUNT (no "items" suffix).
      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.text(dayNames[day.weekday - 1]),
        ),
        findsOneWidget,
      );
      final count = day.weekday == DateTime.wednesday ? '3' : '2';
      expect(
        find.descendant(of: find.byKey(key), matching: find.text(count)),
        findsOneWidget,
        reason: '${iso(day)} resolves its placeholder ($count)',
      );
      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.text(day.weekday == DateTime.wednesday ? '2' : '3'),
        ),
        findsNothing,
      );
      // READ-THROUGH (P4.1): counting the day wrote no days row — a
      // materialization would have pinned it to a forked timer.
      expect(
        await store.dayPlanId(day),
        isNull,
        reason: 'rendering must not materialize ${iso(day)}',
      );
    }

    // Rows run Monday → Sunday in order, and today (inside this week by
    // construction) is among them.
    expect(
      tester.getTopLeft(find.byKey(Key('day-${iso(monday)}'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(Key('day-${iso(addDays(monday, 6))}'))).dy,
      ),
    );
    expect(find.byKey(Key('day-${iso(day0)}')), findsOneWidget);

    // And no day fork exists anywhere in the board.
    final timers = await store.timersInBoard(controller.board.id);
    expect(timers.every((t) => t.dayDate == null), isTrue);

    controller.dispose();
    await store.close();
  });

  testWidgets('month_rows_show_every_day_of_the_shown_month', (tester) async {
    await pumpBoard(tester);
    await openCalendar(tester);
    await tester.tap(find.byKey(const Key('bar-view-toggle')));
    await settle(tester);

    final day0 = today();
    final count = daysInMonth(day0);
    expect(dayRows(), findsNWidgets(count));
    for (var d = 1; d <= count; d++) {
      final day = DateTime(day0.year, day0.month, d);
      final key = Key('day-${iso(day)}');
      expect(find.byKey(key), findsOneWidget, reason: 'month day ${iso(day)}');
      // Same row shape as the week view: name … count.
      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.text(dayNames[day.weekday - 1]),
        ),
        findsOneWidget,
      );
      if (d == day0.day) {
        final expected = day0.weekday == DateTime.wednesday ? '3' : '2';
        expect(
          find.descendant(of: find.byKey(key), matching: find.text(expected)),
          findsOneWidget,
        );
        // Today keeps its highlight in month view.
        expect(
          boxOf(tester, find.byKey(key)).border?.top.color,
          AppColors.highlightBorder,
        );
      }
    }
    // Neither neighbour month bleeds into the shown month.
    expect(find.byKey(Key('day-${iso(monthStart(day0, 1))}')), findsNothing);
    expect(find.byKey(Key('day-${iso(monthStart(day0, -1))}')), findsNothing);

    controller.dispose();
    await store.close();
  });

  testWidgets('view_toggle_switches_between_week_and_month', (tester) async {
    await pumpBoard(tester);
    await openCalendar(tester);

    // Week by default (settings flips it later), icon naming the view.
    expect(dayRows(), findsNWidgets(7));
    expect(
      (tester
              .widget<IconButton>(find.byKey(const Key('bar-view-toggle')))
              .icon as Icon)
          .icon!,
      Icons.calendar_view_week,
    );

    await tester.tap(find.byKey(const Key('bar-view-toggle')));
    await settle(tester);
    expect(dayRows(), findsNWidgets(daysInMonth(today())));
    expect(
      (tester
              .widget<IconButton>(find.byKey(const Key('bar-view-toggle')))
              .icon as Icon)
          .icon!,
      Icons.calendar_view_month,
    );

    await tester.tap(find.byKey(const Key('bar-view-toggle')));
    await settle(tester);
    expect(dayRows(), findsNWidgets(7));
    expect(
      (tester
              .widget<IconButton>(find.byKey(const Key('bar-view-toggle')))
              .icon as Icon)
          .icon!,
      Icons.calendar_view_week,
    );

    controller.dispose();
    await store.close();
  });

  // ── P4.2 rule 2: highlighting ──────────────────────────────────────────

  testWidgets('todays_row_carries_the_highlight_tokens', (tester) async {
    await pumpBoard(tester);
    await openCalendar(tester);

    final day0 = today();
    final todayBox = boxOf(tester, find.byKey(Key('day-${iso(day0)}')));
    expect(todayBox.border?.top.color, AppColors.highlightBorder);
    expect(todayBox.color, AppColors.highlight);

    // Any other day of the shown week is the plain card row.
    final other = [
      for (var i = 0; i < 7; i++) addDays(mondayOf(day0), i),
    ].firstWhere((d) => d != day0);
    final plainBox = boxOf(tester, find.byKey(Key('day-${iso(other)}')));
    expect(plainBox.border?.top.color, AppColors.cardBorder);
    expect(plainBox.color, AppColors.card);

    controller.dispose();
    await store.close();
  });

  // ── P4.2 rule 4: the date setter ───────────────────────────────────────

  testWidgets('date_setter_steps_the_grid_picks_and_highlights', (
    tester,
  ) async {
    await pumpBoard(tester);
    await openCalendar(tester);

    final day0 = today();
    await tester.tap(find.byKey(const Key('bar-date-setter')));
    await settle(tester);

    // The popup opens on the SHOWN month …
    expect(find.byKey(const Key('cal-pick-month')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('cal-pick-month'))).data,
      monthLabel(day0),
    );
    expect(find.byKey(Key('pick-${iso(day0)}')), findsOneWidget);

    // … with month stepping.
    await tester.tap(find.byKey(const Key('cal-pick-next')));
    await settle(tester);
    final next = monthStart(day0, 1);
    expect(
      tester.widget<Text>(find.byKey(const Key('cal-pick-month'))).data,
      monthLabel(next),
    );
    expect(find.byKey(Key('pick-${iso(next)}')), findsOneWidget);

    // Pick the next month's 15th (any month has one).
    final target = DateTime(next.year, next.month, 15);
    await tester.tap(find.byKey(Key('pick-${iso(target)}')));
    await settle(tester);

    // Picker closed; the shown range is now the picked day's WEEK, its
    // row highlighted, counts still read through after the jump.
    expect(find.byKey(const Key('cal-pick-month')), findsNothing);
    expect(dayRows(), findsNWidgets(7));
    final monday = mondayOf(target);
    for (var i = 0; i < 7; i++) {
      expect(
        find.byKey(Key('day-${iso(addDays(monday, i))}')),
        findsOneWidget,
        reason: 'the picked day\'s week is shown',
      );
    }
    expect(
      find.byKey(Key('day-${iso(day0)}')),
      findsNothing,
      reason: 'today is outside the picked day\'s week',
    );
    expect(
      boxOf(tester, find.byKey(Key('day-${iso(target)}'))).border?.top.color,
      AppColors.highlightBorder,
    );
    expect(
      find.descendant(
        of: find.byKey(Key('day-${iso(target)}')),
        matching: find.text('2'),
      ),
      findsOneWidget,
      reason: 'the picked day resolves the global default (count 2)',
    );

    controller.dispose();
    await store.close();
  });

  // ── P4.2 rule 3: the edge chevrons ─────────────────────────────────────

  testWidgets('edge_chevrons_page_the_week_view', (tester) async {
    await pumpBoard(tester);
    await openCalendar(tester);

    final day0 = today();
    final monday = mondayOf(day0);

    // Both chevrons hidden until their edge is hovered.
    Finder prevReveal() =>
        find.byKey(const Key('cal-prev-reveal'));
    Finder nextReveal() =>
        find.byKey(const Key('cal-next-reveal'));
    expect(tester.widget<AnimatedOpacity>(prevReveal()).opacity, 0.0);
    expect(tester.widget<AnimatedOpacity>(nextReveal()).opacity, 0.0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    // Hovering the LEFT edge strip reveals the previous chevron only …
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('cal-gutter-left'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AnimatedOpacity>(prevReveal()).opacity, 1.0);
    expect(tester.widget<AnimatedOpacity>(nextReveal()).opacity, 0.0);

    await tester.tap(find.byKey(const Key('cal-prev')));
    await settle(tester);

    // … previous week: the same weekdays 7 days back.
    expect(dayRows(), findsNWidgets(7));
    expect(
      find.byKey(Key('day-${iso(addDays(monday, -7))}')),
      findsOneWidget,
      reason: 'left pages −7 days',
    );
    expect(find.byKey(Key('day-${iso(monday)}')), findsNothing);
    expect(find.byKey(Key('day-${iso(day0)}')), findsNothing);

    // The RIGHT edge reveals the next chevron (and hides the left one).
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('cal-gutter-right'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<AnimatedOpacity>(nextReveal()).opacity, 1.0);
    expect(tester.widget<AnimatedOpacity>(prevReveal()).opacity, 0.0);

    // Two steps forward: today's week again, then the next one.
    await tester.tap(find.byKey(const Key('cal-next')));
    await settle(tester);
    expect(find.byKey(Key('day-${iso(monday)}')), findsOneWidget);
    expect(find.byKey(Key('day-${iso(day0)}')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cal-next')));
    await settle(tester);
    expect(dayRows(), findsNWidgets(7));
    expect(
      find.byKey(Key('day-${iso(addDays(monday, 7))}')),
      findsOneWidget,
      reason: 'right pages +7 days',
    );
    expect(find.byKey(Key('day-${iso(day0)}')), findsNothing);

    controller.dispose();
    await store.close();
  });

  testWidgets('edge_chevrons_page_the_month_view', (tester) async {
    await pumpBoard(tester);
    await openCalendar(tester);
    await tester.tap(find.byKey(const Key('bar-view-toggle')));
    await settle(tester);

    final day0 = today();
    expect(dayRows(), findsNWidgets(daysInMonth(day0)));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    // Right edge → next month.
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('cal-gutter-right'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const Key('cal-next-reveal')))
          .opacity,
      1.0,
    );
    await tester.tap(find.byKey(const Key('cal-next')));
    await settle(tester);

    final next = monthStart(day0, 1);
    expect(dayRows(), findsNWidgets(daysInMonth(next)));
    expect(find.byKey(Key('day-${iso(next)}')), findsOneWidget);
    expect(find.byKey(Key('day-${iso(day0)}')), findsNothing);

    // Left edge → back (today's month), then the previous month.
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('cal-gutter-left'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const Key('cal-prev-reveal')))
          .opacity,
      1.0,
    );
    await tester.tap(find.byKey(const Key('cal-prev')));
    await settle(tester);
    expect(dayRows(), findsNWidgets(daysInMonth(day0)));
    expect(find.byKey(Key('day-${iso(day0)}')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cal-prev')));
    await settle(tester);
    final prev = monthStart(day0, -1);
    expect(dayRows(), findsNWidgets(daysInMonth(prev)));
    expect(find.byKey(Key('day-${iso(prev)}')), findsOneWidget);
    expect(find.byKey(Key('day-${iso(day0)}')), findsNothing);

    controller.dispose();
    await store.close();
  });

  // ── P4.2 rule 3: tap → that day's board ────────────────────────────────

  testWidgets('tapping_a_day_opens_that_days_board_and_home_returns', (
    tester,
  ) async {
    await pumpBoard(tester);
    await openCalendar(tester);

    // The Monday row — a Routine day (the one-off rule claims only the
    // week's Wednesday, so this never depends on which day t0 falls on).
    final monday = mondayOf(today());
    final rowKey = Key('day-${iso(monday)}');

    await tester.tap(find.byKey(rowKey));
    await settle(tester);

    // The day's board: the plan bar's home/back over the day's RESOLVED
    // plan (routine → `row-r1`), opened read-only.
    expect(find.byKey(const Key('plan-bar')), findsOneWidget);
    expect(find.byKey(const Key('row-r1')), findsOneWidget);
    expect(await store.dayPlanId(monday), isNull, reason: 'open never forks');

    // Back → the Calendar (the day board went with its controller).
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('plan-bar')),
        matching: find.byKey(const Key('bar-back')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('plan-bar')), findsNothing);
    expect(find.byKey(Key('row-r1')), findsNothing);
    expect(find.byKey(const Key('calendar-page')), findsOneWidget);

    // Open again; HOME pops to the board root — the Calendar goes too.
    await tester.tap(find.byKey(rowKey));
    await settle(tester);
    expect(find.byKey(const Key('plan-bar')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('plan-bar')),
        matching: find.byKey(const Key('bar-home')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('plan-bar')), findsNothing);
    expect(find.byKey(const Key('calendar-page')), findsNothing);
    expect(find.byKey(const Key('main-bar')), findsOneWidget);

    controller.dispose();
    await store.close();
  });
}

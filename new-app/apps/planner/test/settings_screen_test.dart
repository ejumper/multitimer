import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/settings_service.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Settings page widget tests (v2 P5.2): the outline's Settings section.
///
/// Pinned here: the main bar's Settings button ALIVE and pushing the
/// page, whose own bar is HOME ONLY · every switch/radio reflects its
/// default (Overwrite OFF · Home = current day · Auto-finish OFF /
/// Duration ON / Time OFF · calendar week) · the switches PERSIST — each
/// write lands in the store's `settings` table and survives the page
/// being closed and reopened (Home → the board root, since nothing
/// claims today in this fixture) · the Home choice picks a specific plan
/// through the picker dialog (the LIBRARY's plans by name — a day fork
/// never appears), persists, and the Bottom Bar section's read-only line
/// echoes the Home definition · the Calendar default view choice
/// persists and FEEDS the calendar (reopening it lands in month).
///
/// Fixture: `Routine` + `Errands` as ordinary Library plans and one
/// DAY-OWNED plan (`Lived day`) that must stay out of the picker; no
/// default rules — nothing claims today, so Home falls back to the board
/// root and the Settings button stays reachable after a Home press.
///
/// The board's 1 Hz ticker hangs pumpAndSettle — every pump here is
/// bounded through [settle] (`tester.pump()` [+ 300ms] rounds), and the
/// settings-heavy tests ride a taller surface so every row is reachable
/// without scrolling gymnastics.
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late AppController controller;
  late IntervalTimer routine;
  late IntervalTimer errands;
  late IntervalTimer livedDay;

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
    // A DAY-OWNED plan (P4.1): lives under its day and must never show
    // up as a Home picker option (the Library rule).
    livedDay = await store.createTimer(
      boardId: board.id,
      name: 'Lived day',
      color: '#ff00b1',
      dayDate: dayNumber(DateTime(2026, 3, 1)),
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
  /// `pump()` + 300ms cover route transitions (150ms), the settings
  /// loads, and the store's async write/read chains between frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  /// A surface tall enough for the whole settings list (same
  /// accommodation as the editor/capture tests).
  Future<void> pumpRootBoard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: BoardScreen(controller)));
    await tester.pump();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('bar-settings')));
    await settle(tester);
    expect(find.byKey(const Key('settings-page')), findsOneWidget);
  }

  /// Home from the settings bar → the board root (nothing claims today
  /// in this fixture), then the Settings page again.
  Future<void> reopenSettings(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('settings-bar')),
        matching: find.byKey(const Key('bar-home')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('settings-page')), findsNothing);
    expect(find.byKey(const Key('main-bar')), findsOneWidget);
    await openSettings(tester);
  }

  Switch switchOf(WidgetTester tester, String key) =>
      tester.widget<Switch>(find.byKey(Key(key)));

  /// The one Icon inside an option row (the radio glyph).
  Icon iconIn(WidgetTester tester, String rowKey) => tester.widget<Icon>(
    find.descendant(of: find.byKey(Key(rowKey)), matching: find.byType(Icon)),
  );

  // ── the navigation shell ────────────────────────────────────────────────

  testWidgets('settings_button_opens_the_page_with_a_home_only_bar', (
    tester,
  ) async {
    await pumpRootBoard(tester);
    await openSettings(tester);

    expect(find.text('Settings'), findsOneWidget);

    // Its own bar: HOME ONLY (P5.2 rule 6 — the outline's bar).
    final buttons = find.descendant(
      of: find.byKey(const Key('settings-bar')),
      matching: find.byType(IconButton),
    );
    expect(buttons, findsOneWidget);
    expect(
      tester.widget<IconButton>(buttons).key!,
      const Key('bar-home'),
      reason: 'the settings bar carries nothing but home',
    );

    // Every section of the outline's Settings section is on the page.
    for (final section in [
      'NEW EVENTS',
      'HOME',
      'INTERVAL OPTIONS DEFAULTS',
      'CALENDAR',
      'BOTTOM BAR',
    ]) {
      expect(find.text(section), findsOneWidget, reason: section);
    }

    controller.dispose();
    await store.close();
  });

  // ── defaults + persistence ──────────────────────────────────────────────

  testWidgets('switches_reflect_defaults_and_persist_values', (tester) async {
    await pumpRootBoard(tester);
    await openSettings(tester);

    // Defaults, straight off the unseeded page …
    expect(
      switchOf(tester, 'set-new-event-override').value,
      isFalse,
      reason: 'New events override default = OFF',
    );
    expect(switchOf(tester, 'set-default-autofinish').value, isFalse);
    expect(switchOf(tester, 'set-default-duration').value, isTrue);
    expect(switchOf(tester, 'set-default-time').value, isFalse);
    // … and straight out of a fresh store (nothing written yet).
    expect(await store.getSetting(kSettingEventOverridesDefault), isNull);
    expect(await store.getSetting(kSettingIntervalDuration), isNull);

    // Flip the New events override ON — persisted immediately.
    await tester.ensureVisible(find.byKey(const Key('set-new-event-override')));
    await tester.tap(find.byKey(const Key('set-new-event-override')));
    await settle(tester);
    expect(switchOf(tester, 'set-new-event-override').value, isTrue);
    expect(
      await store.getSetting(kSettingEventOverridesDefault),
      '1',
      reason: 'the switch writes through to the settings table',
    );

    // Duration default OFF lands Auto-finish OFF beside it — the pair can
    // never hold the invalid ON/OFF combination (the engine contract),
    // and the Auto-finish switch stands down while Duration is OFF.
    await tester.ensureVisible(find.byKey(const Key('set-default-duration')));
    await tester.tap(find.byKey(const Key('set-default-duration')));
    await settle(tester);
    expect(switchOf(tester, 'set-default-duration').value, isFalse);
    expect(switchOf(tester, 'set-default-autofinish').value, isFalse);
    expect(switchOf(tester, 'set-default-autofinish').onChanged, isNull);
    expect(await store.getSetting(kSettingIntervalDuration), '0');
    expect(await store.getSetting(kSettingIntervalAutoFinish), '0');

    await tester.ensureVisible(find.byKey(const Key('set-default-time')));
    await tester.tap(find.byKey(const Key('set-default-time')));
    await settle(tester);
    expect(switchOf(tester, 'set-default-time').value, isTrue);
    expect(await store.getSetting(kSettingIntervalTime), '1');

    // Close the page and reopen it: every value survived.
    await reopenSettings(tester);
    expect(switchOf(tester, 'set-new-event-override').value, isTrue);
    expect(switchOf(tester, 'set-default-duration').value, isFalse);
    expect(switchOf(tester, 'set-default-autofinish').value, isFalse);
    expect(switchOf(tester, 'set-default-time').value, isTrue);

    controller.dispose();
    await store.close();
  });

  // ── Home: a specific plan ───────────────────────────────────────────────

  testWidgets('home_picks_a_specific_plan_and_the_bottom_bar_echoes_it', (
    tester,
  ) async {
    await pumpRootBoard(tester);
    await openSettings(tester);

    // Default: Current day's timer is the selected side.
    expect(
      iconIn(tester, 'set-home-current-day').icon,
      Icons.radio_button_checked,
    );
    expect(
      iconIn(tester, 'set-home-specific-plan').icon,
      Icons.radio_button_unchecked,
    );
    expect(find.byKey(const Key('set-home-plan')), findsNothing);

    // The Bottom Bar section's single line echoes the current-day home.
    expect(
      find.descendant(
        of: find.byKey(const Key('set-bottom-bar-home')),
        matching: find.text('Opens the current day\u2019s timer'),
      ),
      findsOneWidget,
    );

    // Choosing "A specific plan" opens the picker over the LIBRARY's
    // plans by name — the day-owned plan is not one of them.
    await tester.ensureVisible(find.byKey(const Key('set-home-specific-plan')));
    await tester.tap(find.byKey(const Key('set-home-specific-plan')));
    await settle(tester);
    expect(find.text('Choose a plan'), findsOneWidget);
    expect(find.byKey(Key('home-plan-${routine.id}')), findsOneWidget);
    expect(find.byKey(Key('home-plan-${errands.id}')), findsOneWidget);
    expect(
      find.byKey(Key('home-plan-${livedDay.id}')),
      findsNothing,
      reason: 'a day fork never appears in the Library picker',
    );

    await tester.tap(find.byKey(Key('home-plan-${errands.id}')));
    await settle(tester);
    expect(find.text('Choose a plan'), findsNothing); // picked → closed

    expect(
      iconIn(tester, 'set-home-specific-plan').icon,
      Icons.radio_button_checked,
    );
    expect(
      iconIn(tester, 'set-home-current-day').icon,
      Icons.radio_button_unchecked,
    );
    expect(
      await store.getSetting(kSettingHomePlanId),
      errands.id,
      reason: 'the choice persists as the Home plan id',
    );

    // The plan row names the pick and the Bottom Bar line echoes it.
    expect(
      find.descendant(
        of: find.byKey(const Key('set-home-plan')),
        matching: find.text('Errands'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('set-bottom-bar-home')),
        matching: find.text('Opens Errands'),
      ),
      findsOneWidget,
    );

    // Survives close + reopen: still "A specific plan", still Errands.
    // (Close by popping the route — with a plan home, the bar's home
    // would push that plan's board instead of the root.)
    Navigator.of(
      tester.element(find.byKey(const Key('settings-page'))),
    ).pop();
    await settle(tester);
    expect(find.byKey(const Key('settings-page')), findsNothing);
    expect(find.byKey(const Key('main-bar')), findsOneWidget); // the root
    await openSettings(tester);
    expect(
      iconIn(tester, 'set-home-specific-plan').icon,
      Icons.radio_button_checked,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('set-home-plan')),
        matching: find.text('Errands'),
      ),
      findsOneWidget,
    );

    controller.dispose();
    await store.close();
  });

  // ── Calendar default view ───────────────────────────────────────────────

  testWidgets('calendar_view_choice_persists_and_feeds_the_calendar', (
    tester,
  ) async {
    await pumpRootBoard(tester);
    await openSettings(tester);

    // Week is the default side of the two-way choice.
    expect(iconIn(tester, 'set-cal-week').icon, Icons.radio_button_checked);
    expect(iconIn(tester, 'set-cal-month').icon, Icons.radio_button_unchecked);
    expect(await store.getSetting(kSettingCalendarDefaultView), isNull);

    await tester.ensureVisible(find.byKey(const Key('set-cal-month')));
    await tester.tap(find.byKey(const Key('set-cal-month')));
    await settle(tester);
    expect(iconIn(tester, 'set-cal-month').icon, Icons.radio_button_checked);
    expect(iconIn(tester, 'set-cal-week').icon, Icons.radio_button_unchecked);
    expect(
      await store.getSetting(kSettingCalendarDefaultView),
      kCalendarViewMonth,
    );

    // FEEDS ITS CONSUMER: back to the board, open the Calendar — it
    // lands in MONTH (the view toggle names month; a day outside the
    // fixture's initial week renders).
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('settings-bar')),
        matching: find.byKey(const Key('bar-home')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('settings-page')), findsNothing);
    await tester.tap(find.byKey(const Key('bar-calendar')));
    await settle(tester);
    expect(find.byKey(const Key('calendar-page')), findsOneWidget);
    expect(
      (tester
              .widget<IconButton>(find.byKey(const Key('bar-view-toggle')))
              .icon as Icon)
          .icon!,
      Icons.calendar_view_month,
      reason: 'the calendar opens in the configured view',
    );
    expect(
      find.byKey(const Key('day-2026-03-15')),
      findsOneWidget,
      reason: 'a mid-March day exists only in the month list',
    );

    controller.dispose();
    await store.close();
  });
}

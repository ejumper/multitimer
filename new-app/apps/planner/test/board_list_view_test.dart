import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/interval_rows.dart';
import 'package:planner/theme.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Board list-view widget tests (v2 P2.1 — "the dial dies"): the board's
/// main area is the interval LIST over the authored TREE (defs + groups,
/// not the flattened occurrences), each row mapped onto the live run.
///
/// Pinned here: rows render from the tree with group repeat counters · the
/// current row shows `<left>/<total>` with its live fill fraction · dated
/// rows show `15:30`, Open rows show `open` · completed/passed rows render
/// semi-transparent (the Opacity mechanism) · `wait` + pulsing border at a
/// hold · the awaitingWall countdown · the `late` badge · the suspended
/// row's frozen remaining · the checkbox tap · the dial's absence.
///
/// Main fixture (saved BEFORE init) — ordinals in parentheses:
/// `a 'break' 60s manual (0)` · `G(g1 ×2){b 'Cards' 30s auto} (1,2)` ·
/// `d 'Wrap' 45s auto (3)` · `w 'Meeting' 30s dated 15:30 (4)` ·
/// `o 'Notes' Open (5)`.
///
/// The board's heartbeat ticker and the hold pulse hang pumpAndSettle —
/// every pump here is bounded (`tester.pump()` [+ a fixed duration]).
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late AppController controller;

  /// The main fixture described in the file doc.
  Future<void> buildFixture() async {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);

    final board = await store.createBoard('My Board');
    final timer = await store.createTimer(
      boardId: board.id,
      name: 'Interval timer',
      color: '#0055ff',
    );
    await store.saveTree(
      timer.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'a',
            timerId: timer.id,
            name: 'break',
            color: '#0055ff',
            durationSeconds: 60,
            autoFinish: false,
          ),
        ),
        GroupNode(GroupDef(id: 'g1', timerId: timer.id, repeatCount: 2), [
          DefNode(
            IntervalDef(
              id: 'b',
              timerId: timer.id,
              name: 'Cards',
              color: '#ff00b1',
              durationSeconds: 30,
              autoFinish: true,
            ),
          ),
        ]),
        DefNode(
          IntervalDef(
            id: 'd',
            timerId: timer.id,
            name: 'Wrap',
            color: '#00ad6b',
            durationSeconds: 45,
            autoFinish: true,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'w',
            timerId: timer.id,
            name: 'Meeting',
            color: '#b8ff00',
            durationSeconds: 30,
            autoFinish: true,
            triggerTimeSeconds: 55800, // 15:30
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'o',
            timerId: timer.id,
            name: 'Notes',
            color: '#e2e2e2',
            durationSeconds: null, // Open
            autoFinish: false,
          ),
        ),
      ]),
      eventKind: 'tree.save',
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

  /// Two defs only — `a 'break' 60s manual (0)` and the dated
  /// `w 'Meeting' 30s (1)` firing at [trigger] seconds since midnight —
  /// for the wall states (awaitingWall / late / suspended).
  Future<void> buildWallFixture({required int trigger}) async {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);

    final board = await store.createBoard('My Board');
    final timer = await store.createTimer(
      boardId: board.id,
      name: 'Interval timer',
      color: '#0055ff',
    );
    await store.saveTree(
      timer.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'a',
            timerId: timer.id,
            name: 'break',
            color: '#0055ff',
            durationSeconds: 60,
            autoFinish: false,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'w',
            timerId: timer.id,
            name: 'Meeting',
            color: '#b8ff00',
            durationSeconds: 30,
            autoFinish: true,
            triggerTimeSeconds: trigger,
          ),
        ),
      ]),
      eventKind: 'tree.save',
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

  setUp(() => buildFixture());

  Future<void> pumpBoard(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: BoardScreen(controller)));
  }

  /// The duration slot's text of the row for [id] (the keyed shape Text).
  String timeText(WidgetTester tester, String id) =>
      tester.widget<Text>(find.byKey(Key('time-$id'))).data!;

  /// The row's opacity — completed/passed rows render at the shared
  /// dimmed-content alpha, live rows at 1.0.
  double rowOpacity(WidgetTester tester, String id) =>
      tester.widget<Opacity>(find.byKey(Key('row-$id'))).opacity;

  /// The row's progress-fill fraction, read off the [RowFill] widget.
  double fillFraction(WidgetTester tester, String id) =>
      tester.widget<RowFill>(find.byKey(Key('fill-$id'))).fraction;

  /// The group row's repeat counter text (repeats LEFT on the board).
  String repeatText(WidgetTester tester, String id) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(Key('repeat-$id')),
          matching: find.byType(Text),
        ),
      )
      .data!;

  // 1. Rows render from the TREE: every def and every group — 'Cards'
  //    appears ONCE despite its two passes (the flattened list would show
  //    it twice) — with nested children, the group's repeat counter, and
  //    the authored static shapes at notStarted.
  testWidgets('rows_render_tree_defs_and_groups', (tester) async {
    await pumpBoard(tester);

    expect(find.byKey(const Key('interval-list')), findsOneWidget);
    for (final id in ['a', 'g1', 'b', 'd', 'w', 'o']) {
      expect(find.byKey(Key('row-$id')), findsOneWidget, reason: 'no $id');
    }
    // Titles inside their rows.
    expect(
      find.descendant(
        of: find.byKey(const Key('row-a')),
        matching: find.text('break'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('row-b')),
        matching: find.text('Cards'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('row-d')),
        matching: find.text('Wrap'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('row-w')),
        matching: find.text('Meeting'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('row-o')),
        matching: find.text('Notes'),
      ),
      findsOneWidget,
    );
    // The group nests its children (editor chrome) and counts 2 passes.
    expect(
      find.ancestor(
        of: find.byKey(const Key('row-b')),
        matching: find.byKey(const Key('row-g1')),
      ),
      findsOneWidget,
    );
    expect(repeatText(tester, 'g1'), '2');
    // Authored static shapes: duration / wall time / open.
    expect(timeText(tester, 'a'), '1m');
    expect(timeText(tester, 'b'), '30s');
    expect(timeText(tester, 'd'), '45s');
    expect(timeText(tester, 'w'), '15:30');
    expect(timeText(tester, 'o'), 'open');
    // The readout and the control row survive beside the list (P2.4
    // will slim the readout — not this chunk).
    expect(find.byKey(const Key('readout')), findsOneWidget);
    expect(find.byKey(const Key('control-row')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // 2. The CURRENT row shows the live `<left>/<total>` countdown and its
  //    fill carries the exact elapsed/effective fraction (left-aligned
  //    band over the row's track); future rows stay empty.
  testWidgets('current_row_shows_left_over_total_and_fill', (tester) async {
    await pumpBoard(tester);
    expect(controller.start(), isTrue);
    await tester.pump();
    expect(timeText(tester, 'a'), '1m/1m');
    expect(fillFraction(tester, 'a'), 0.0);

    clock.current = clock.current.add(const Duration(seconds: 30));
    await controller.tick();
    await tester.pump();

    expect(timeText(tester, 'a'), '30s/1m');
    expect(fillFraction(tester, 'a'), moreOrLessEquals(0.5, epsilon: 0.001));
    expect(fillFraction(tester, 'b'), 0.0); // future rows stay empty
    expect(fillFraction(tester, 'd'), 0.0);

    // The band is left-aligned and covers exactly the fraction of the
    // fill track (structure — no goldens).
    final track = tester.getRect(find.byKey(const Key('fill-a')));
    final band = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('fill-a')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(band.left, moreOrLessEquals(track.left, epsilon: 0.5));
    expect(band.width / track.width, moreOrLessEquals(0.5, epsilon: 0.02));

    controller.dispose();
    await store.close();
  });

  // 3. Dated rows keep their wall time while future; Open rows show
  //    `open` — through a live run as well as at rest.
  testWidgets('dated_and_open_rows_show_authored_shape', (tester) async {
    await pumpBoard(tester);
    expect(timeText(tester, 'w'), '15:30');
    expect(timeText(tester, 'o'), 'open');

    expect(controller.start(), isTrue);
    await tester.pump();
    expect(timeText(tester, 'w'), '15:30'); // still future mid-run
    expect(timeText(tester, 'o'), 'open');

    controller.dispose();
    await store.close();
  });

  // 4. Completed (marked) rows and rows whose occurrences have all
  //    passed render SEMI-TRANSPARENT — the Opacity mechanism at the
  //    shared dimmed-content alpha; the checkbox lights with the mark and
  //    the mark toggles freely.
  testWidgets('completed_and_passed_rows_are_dimmed', (tester) async {
    await pumpBoard(tester);
    expect(rowOpacity(tester, 'a'), 1.0);
    expect(rowOpacity(tester, 'b'), 1.0);

    // Mark the item → dim + checked; the untouched row stays live.
    controller.toggleMark(0);
    await tester.pump();
    expect(rowOpacity(tester, 'a'), AppColors.dimmed.a);
    expect(
      find.descendant(
        of: find.byKey(const Key('check-a')),
        matching: find.byType(Icon),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('check-b')),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    expect(rowOpacity(tester, 'b'), 1.0);

    // Un-check → full opacity again (marks toggle freely).
    controller.toggleMark(0);
    await tester.pump();
    expect(rowOpacity(tester, 'a'), 1.0);

    // A passed-but-unmarked row dims too (the dial's dimmed ticks, as
    // rows): start, skip past 'break'.
    expect(controller.start(), isTrue);
    await tester.pump();
    expect(controller.skipNext(), isTrue);
    await tester.pump();
    expect(rowOpacity(tester, 'a'), AppColors.dimmed.a);
    expect(rowOpacity(tester, 'b'), 1.0);

    controller.dispose();
    await store.close();
  });

  // 5. HOLD (awaitingAdvance): the held row's slot shows `wait`, its
  //    border PULSES (the »tap-to-continue FadeTransition vocabulary),
  //    and the card's static border stands down — bounded pumps only,
  //    the pulse hangs pumpAndSettle.
  testWidgets('hold_shows_wait_with_pulsing_border', (tester) async {
    await pumpBoard(tester);
    expect(controller.start(), isTrue);
    await tester.pump();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();

    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    expect(timeText(tester, 'a'), 'wait');
    expect(find.byKey(const Key('hold-pulse-a')), findsOneWidget);
    final pulse = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byKey(const Key('hold-pulse-a')),
        matching: find.byType(FadeTransition),
      ),
    );
    // The pulse animates (0.35 ↔ 1.0 over 900ms — the shared vocabulary).
    final before = pulse.opacity.value;
    await tester.pump(const Duration(milliseconds: 450));
    expect(
      tester
          .widget<FadeTransition>(
            find.descendant(
              of: find.byKey(const Key('hold-pulse-a')),
              matching: find.byType(FadeTransition),
            ),
          )
          .opacity
          .value,
      isNot(equals(before)),
    );
    // The card's static border stands down for the pulsing one; only the
    // held row is affected.
    final card = tester.widget<IntervalChipCard>(
      find.descendant(
        of: find.byKey(const Key('row-a')),
        matching: find.byType(IntervalChipCard),
      ),
    );
    expect(card.bordered, isFalse);
    expect(find.byKey(const Key('hold-pulse-b')), findsNothing);
    expect(timeText(tester, 'b'), '30s');

    controller.dispose();
    await store.close();
  });

  // 6. AWAITING WALL: the pending wall's row shows the live countdown
  //    (snapshot.remaining is exactly that), with no fill — and the rows
  //    behind the cursor are dimmed while the wall waits.
  testWidgets('awaiting_wall_row_shows_countdown', (tester) async {
    await buildWallFixture(trigger: 55800); // 15:30
    await pumpBoard(tester);
    expect(controller.start(), isTrue);
    await tester.pump();
    clock.current = clock.current.add(const Duration(seconds: 60)); // 08:01
    await controller.tick();
    await tester.pump();
    expect(controller.snapshot.state, SessionState.awaitingAdvance);

    expect(controller.skipNext(), isTrue);
    await tester.pump();
    expect(controller.snapshot.state, SessionState.awaitingWall);
    // 08:01 → 15:30 = 7h29m left, ticking live on the wall's row.
    expect(timeText(tester, 'w'), '7h29m');
    expect(fillFraction(tester, 'w'), 0.0); // not fired — no progress
    expect(rowOpacity(tester, 'w'), 1.0); // the waiting row is not dimmed
    expect(rowOpacity(tester, 'a'), AppColors.dimmed.a); // passed
    expect(timeText(tester, 'a'), '1m'); // authored shape behind the wait

    controller.dispose();
    await store.close();
  });

  // 7. LATE: a wall firing after its trigger carries a small `late`
  //    badge on the CURRENT row — and that row plays like any other
  //    current row (`<left>/<total>`), not its wall time.
  testWidgets('late_badge_on_current_row', (tester) async {
    await buildWallFixture(trigger: 28805); // 08:00:05 — 5s after t0
    await pumpBoard(tester);
    expect(controller.start(), isTrue);
    await tester.pump();
    clock.current = clock.current.add(const Duration(seconds: 10)); // late
    await controller.tick();
    await tester.pump();

    expect(controller.snapshot.state, SessionState.running);
    expect(controller.snapshot.late, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const Key('row-w')),
        matching: find.text('late'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('row-a')),
        matching: find.text('late'),
      ),
      findsNothing,
    );
    expect(timeText(tester, 'w'), '30s/30s'); // current like any other

    controller.dispose();
    await store.close();
  });

  // 8. SUSPENDED: the wall interrupted 'break' mid-flight — its row shows
  //    the FROZEN remaining instead of running progress, keeps its
  //    elapsed fill, and stays live (it will resume).
  testWidgets('suspended_row_shows_frozen_remaining', (tester) async {
    await buildWallFixture(trigger: 28805); // 08:00:05
    await pumpBoard(tester);
    expect(controller.start(), isTrue);
    await tester.pump();
    clock.current = clock.current.add(const Duration(seconds: 10));
    await controller.tick();
    await tester.pump();

    expect(controller.snapshot.suspendedOrdinal, 0);
    expect(controller.snapshot.suspendedRemaining, const Duration(seconds: 55));
    expect(timeText(tester, 'a'), '55s/1m'); // frozen at 55s of its 1m
    expect(fillFraction(tester, 'a'), moreOrLessEquals(5 / 60, epsilon: 0.001));
    expect(rowOpacity(tester, 'a'), 1.0); // suspended ≠ passed

    controller.dispose();
    await store.close();
  });

  // 9. The dial is GONE (P2.1): no dial widget, the list is the main
  //    area, and the readout/control row remain (P2.4 slims them).
  testWidgets('dial_is_gone_list_is_the_main_area', (tester) async {
    await pumpBoard(tester);

    expect(find.byKey(const Key('dial')), findsNothing);
    expect(find.byKey(const Key('interval-list')), findsOneWidget);
    expect(find.byKey(const Key('readout')), findsOneWidget);
    expect(find.byKey(const Key('control-row')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // 10. Groups: the repeat counter counts DOWN (repeats LEFT) and the
  //     group's aggregate fill covers its occurrences' total progress.
  testWidgets('group_repeats_count_down_with_aggregate_fill', (tester) async {
    await pumpBoard(tester);
    expect(repeatText(tester, 'g1'), '2'); // fresh run: 2 passes left
    expect(fillFraction(tester, 'g1'), 0.0);

    expect(controller.start(), isTrue);
    await tester.pump();
    expect(repeatText(tester, 'g1'), '2'); // pass 1 of 2 in progress

    expect(controller.skipNext(), isTrue); // into Cards pass 1 (ordinal 1)
    await tester.pump();
    expect(repeatText(tester, 'g1'), '2'); // that pass has not finished

    expect(controller.skipNext(), isTrue); // into Cards pass 2 (ordinal 2)
    await tester.pump();
    expect(repeatText(tester, 'g1'), '1'); // one pass gone, one left
    expect(fillFraction(tester, 'g1'), moreOrLessEquals(0.5, epsilon: 0.001));

    expect(controller.skipNext(), isTrue); // past the group (ordinal 3)
    await tester.pump();
    expect(repeatText(tester, 'g1'), '0'); // every pass played
    expect(fillFraction(tester, 'g1'), 1.0);

    controller.dispose();
    await store.close();
  });

  // 11. Fills track the cursor: full behind it, live on the current row,
  //     empty ahead of it — across a skip and a jump.
  testWidgets('fills_track_passed_and_future_rows', (tester) async {
    await pumpBoard(tester);
    expect(controller.start(), isTrue);
    await tester.pump();
    expect(controller.skipNext(), isTrue); // cursor → Cards pass 1
    await tester.pump();
    expect(fillFraction(tester, 'a'), 1.0); // passed rows fill full
    expect(fillFraction(tester, 'b'), 0.0); // current just started

    clock.current = clock.current.add(const Duration(seconds: 15));
    await controller.tick();
    await tester.pump();
    expect(fillFraction(tester, 'b'), moreOrLessEquals(0.5, epsilon: 0.001));
    expect(fillFraction(tester, 'd'), 0.0); // future rows stay empty
    expect(fillFraction(tester, 'w'), 0.0);

    expect(controller.jumpTo(3), isTrue); // jump past the group
    await tester.pump();
    expect(fillFraction(tester, 'a'), 1.0);
    expect(fillFraction(tester, 'b'), 1.0); // both passes behind the cursor
    expect(fillFraction(tester, 'd'), 0.0); // parked at full remaining

    controller.dispose();
    await store.close();
  });

  // 12. The checkbox slot is wired to the mark (trivial P2.1 wiring; the
  //     full P2.2 semantics ride the next chunk): tap = toggle, the row
  //     dims with its mark.
  testWidgets('checkbox_tap_toggles_completion', (tester) async {
    await pumpBoard(tester);

    await tester.tap(find.byKey(const Key('check-b')));
    await tester.pump();
    expect(controller.session.isCompleted('b'), isTrue);
    expect(rowOpacity(tester, 'b'), AppColors.dimmed.a);
    expect(
      find.descendant(
        of: find.byKey(const Key('check-b')),
        matching: find.byType(Icon),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('check-b')));
    await tester.pump();
    expect(controller.session.isCompleted('b'), isFalse);
    expect(rowOpacity(tester, 'b'), 1.0);
    expect(
      find.descendant(
        of: find.byKey(const Key('check-b')),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );

    controller.dispose();
    await store.close();
  });

  // ── v2 P2.2: the completion interaction ─────────────────────────

  /// Two simple manual/autofinish defs for the interaction tests (no
  /// walls, no repeats).
  Future<void> buildSimpleFixture() async {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);
    final board = await store.createBoard('My Board');
    final timer = await store.createTimer(
      boardId: board.id,
      name: 'Interval timer',
      color: '#0055ff',
    );
    await store.saveTree(
      timer.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'x',
            timerId: timer.id,
            name: 'Study',
            color: '#0055ff',
            durationSeconds: 60,
            autoFinish: false,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'y',
            timerId: timer.id,
            name: 'Store',
            color: '#ff00b1',
            durationSeconds: 60,
            autoFinish: false,
          ),
        ),
      ]),
      eventKind: 'tree.save',
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

  testWidgets('enter_at_hold_completes_and_checks', (tester) async {
    await buildSimpleFixture();
    await pumpBoard(tester);
    controller.start();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.snapshot.state, SessionState.awaitingAdvance);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.session.isCompleted('x'), isTrue);
    expect(controller.snapshot.state, SessionState.running);
    expect(controller.snapshot.ordinal, 1);
    controller.dispose();
  });

  testWidgets('not_completed_button_and_N_advance_unchecked',
      (tester) async {
    await buildSimpleFixture();
    await pumpBoard(tester);
    controller.start();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('btn-not-completed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.session.isCompleted('x'), isFalse);
    expect(controller.snapshot.ordinal, 1);

    // Second hold: the N key does the same.
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.session.isCompleted('y'), isFalse);
    expect(controller.snapshot.state, SessionState.notStarted);
    controller.dispose();
  });

  testWidgets('tap_to_continue_completes_at_a_hold', (tester) async {
    await buildSimpleFixture();
    await pumpBoard(tester);
    controller.start();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('tap-to-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.session.isCompleted('x'), isTrue);
    expect(controller.snapshot.ordinal, 1);
    controller.dispose();
  });

  testWidgets('hold_row_slot_contract', (tester) async {
    await buildSimpleFixture();
    await pumpBoard(tester);
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Running: the list shortcut holds the second slot, no decision button.
    expect(find.byKey(const Key('btn-list')), findsOneWidget);
    expect(find.byKey(const Key('btn-not-completed')), findsNothing);

    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Hold: [adjust][not-completed][reset][silence] — silence keeps the
    // far-right slot (the v1 contract), the list shortcut steps aside.
    final icons = tester
        .widgetList<IconButton>(
          find.descendant(
            of: find.byKey(const Key('control-row')),
            matching: find.byType(IconButton),
          ),
        )
        .toList();
    expect(icons, hasLength(4));
    expect(find.byKey(const Key('btn-not-completed')), findsOneWidget);
    expect(find.byKey(const Key('btn-silence')), findsOneWidget);
    expect(find.byKey(const Key('btn-list')), findsNothing);
    expect(find.byKey(const Key('btn-skip')), findsNothing);
    controller.dispose();
  });

  testWidgets('enter_outside_a_hold_keeps_the_button_model', (tester) async {
    await buildSimpleFixture();
    await pumpBoard(tester);
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The arrow-walk to Reset and Enter activates it (the confirm dialog
    // appears) — Enter is NOT a completion action while running.
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Dialog), findsOneWidget); // the dialog opened
    expect(controller.snapshot.state, SessionState.running); // untouched
    controller.dispose();
  });

  testWidgets('retry_missed_runs_only_the_un_done_items', (tester) async {
    await buildSimpleFixture();
    await pumpBoard(tester);
    // Fresh: nothing to retry.
    expect(find.byKey(const Key('btn-retry-missed')), findsNothing);

    controller.start();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // x completes
    controller.skipNext(); // y skipped = not completed
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.snapshot.state, SessionState.notStarted);

    expect(find.text('Retry missed (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn-retry-missed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // x flew past (its work stands); y runs.
    expect(controller.snapshot.ordinal, 1);
    expect(controller.snapshot.state, SessionState.running);

    // Let y run its course and complete -> all done -> no button.
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.snapshot.state, SessionState.notStarted);
    expect(find.byKey(const Key('btn-retry-missed')), findsNothing);
    controller.dispose();
  });

  testWidgets('reset_un_checks_rows_visibly', (tester) async {
    await buildSimpleFixture();
    await pumpBoard(tester);
    controller.start();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // x checked
    expect(controller.session.isCompleted('x'), isTrue);

    controller.reset();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.session.completedDefIds, isEmpty);
    // The row is back to full opacity (the dimming released).
    expect(rowOpacity(tester, 'x'), 1.0);
    controller.dispose();
  });

  testWidgets('mark_changes_persist_through_the_store', (tester) async {
    await buildSimpleFixture();
    await pumpBoard(tester);
    controller.start();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // x checked
    await tester.pump();

    // The mark is on the DEF in the store (the durable record) and the
    // change log carries the run.mark entry.
    final reloaded = await store.loadTree(controller.timer.id);
    expect((reloaded.nodeById('x') as DefNode).def.completed, isTrue);
    final events = await db.select(db.eventLog).get();
    expect(
      events.any((e) => e.kind == 'run.mark'),
      isTrue,
      reason: 'the mark change is logged',
    );
    controller.dispose();
  });

}

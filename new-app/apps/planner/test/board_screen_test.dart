import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/editor_screen.dart';
import 'package:planner/theme.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Board screen widget tests (P3.1/P3.2): the state-driven readout, the tap
/// and Space dispatch, caption visibility, the editor route, the control
/// row (interval list, reset, skip), and the end-of-timer affordances —
/// over a real AppController on an in-memory drift store with recording
/// adapters.
///
/// Default fixture via [buildFixture]: TWO defs saved BEFORE init — 'break'
/// 60s (manual) and 'Cards' 30s (manual); totalPlanned = 90s. NOTE: 'break'
/// is deliberately a MANUAL (autoFinish=false) instance so its zero-crossing
/// parks the session in awaitingAdvance — test 4 asserts the WAIT chip
/// right after +60s, which the engine only produces for manually-complete
/// instances. The end-of-timer tests rebuild the fixture with a single def
/// and a per-def autoFinish.
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late AppController controller;

  /// Boots a fresh in-memory fixture: board + timer + the given defs saved
  /// BEFORE init. The default is the two-def fixture described above; the
  /// end-of-timer tests swap in a single def with the autoFinish they need.
  Future<void> buildFixture({
    List<({String id, String name, int seconds, bool autoFinish})> defs =
        const [
          (id: 'a', name: 'break', seconds: 60, autoFinish: false),
          (id: 'b', name: 'Cards', seconds: 30, autoFinish: false),
        ],
  }) async {
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
        for (final d in defs)
          DefNode(
            IntervalDef(
              id: d.id,
              timerId: timer.id,
              name: d.name,
              color: '#0055ff',
              durationSeconds: d.seconds,
              autoFinish: d.autoFinish,
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

  // 1. Not started: the planned readout parts of 90s + first caption.
  testWidgets('board_renders_not_started_planned', (tester) async {
    await pumpBoard(tester);

    // Planned parts of 90s: ('00', '01', '30') in the 03H : 00M / 00 layout.
    expect(find.text('00'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    // Caption offers the FIRST instance as next.
    expect(find.text('1. break - 1m'), findsOneWidget);
    expect(find.text('PAUSED'), findsNothing);
    expect(find.text('WAIT'), findsNothing);

    controller.dispose();
    await store.close();
  });

  // 2. Running: hm total on top, big mm:ss, current label, next caption.
  testWidgets('board_renders_running', (tester) async {
    await pumpBoard(tester);
    expect(controller.start(), isTrue);
    await tester.pump();

    expect(find.text('1m'), findsOneWidget); // totalRemaining 90s
    expect(find.text('01:00'), findsOneWidget); // current remaining 60s
    expect(find.text('1. break'), findsOneWidget);
    expect(find.text('2. Cards - 30s'), findsOneWidget);
    expect(find.text('PAUSED'), findsNothing);
    expect(find.text('WAIT'), findsNothing);

    controller.dispose();
    await store.close();
  });

  // 3. Paused: the PAUSED chip joins the big line, which still shows the
  //    frozen remaining.
  testWidgets('board_renders_paused', (tester) async {
    await pumpBoard(tester);
    controller.start();
    await tester.pump();
    controller.pause();
    await tester.pump();

    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);
    expect(find.text('WAIT'), findsNothing);

    controller.dispose();
    await store.close();
  });

  // 4. 'break' zeroed (manual): the board holds at 00:00 with the WAIT
  //    chip; awaitingAdvance swaps the caption for tap-to-continue.
  testWidgets('board_renders_awaiting_advance', (tester) async {
    await pumpBoard(tester);
    controller.start();
    await tester.pump();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();

    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('WAIT'), findsOneWidget);
    expect(find.text('0m'), findsOneWidget); // remaining total: 30s
    // P3.2: awaitingAdvance REPLACES the caption with tap-to-continue.
    expect(find.byKey(const Key('tap-to-continue')), findsOneWidget);
    expect(find.byKey(const Key('caption')), findsNothing);
    expect(find.text('PAUSED'), findsNothing);

    controller.dispose();
    await store.close();
  });

  // 5. Dial taps dispatch the context action for each state in turn.
  testWidgets('tap_dispatches_context_actions', (tester) async {
    await pumpBoard(tester);

    await tester.tap(find.byKey(const Key('dial')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.running);

    await tester.tap(find.byKey(const Key('dial')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.paused);

    await tester.tap(find.byKey(const Key('dial')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.running);

    controller.dispose();
    await store.close();
  });

  // 6. Space performs the same dispatch as a dial tap.
  testWidgets('space_dispatches_context_actions', (tester) async {
    await pumpBoard(tester);
    await tester.pump(); // let autofocus claim the keyboard

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.snapshot.state, SessionState.running);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.snapshot.state, SessionState.paused);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.snapshot.state, SessionState.running);

    controller.dispose();
    await store.close();
  });

  // 7. jumpTo parks on the LAST instance → no caption (nothing is next).
  testWidgets('caption_hidden_at_end', (tester) async {
    await pumpBoard(tester);

    expect(controller.jumpTo(1), isTrue);
    await tester.pump();

    expect(find.byKey(const Key('caption')), findsNothing);

    controller.dispose();
    await store.close();
  });

  // 8. Right-click on the dial opens the interval editor (P4.1).
  testWidgets('right_click_opens_editor_screen', (tester) async {
    await pumpBoard(tester);

    await tester.tap(
      find.byKey(const Key('dial')),
      buttons: kSecondaryMouseButton,
    );
    // The handler is async (loads the tree before pushing) — settle the
    // microtask and the route transition.
    await tester.pumpAndSettle();

    expect(find.byType(EditorScreen), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // 9. btn-list opens the overlay: every instance in order, label+duration.
  testWidgets('list_overlay_contents_in_order', (tester) async {
    await pumpBoard(tester);
    await tester.tap(find.byKey(const Key('btn-list')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('list-overlay')), findsOneWidget);
    expect(find.text('Intervals'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('list-row-0')),
        matching: find.text('1. break'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('list-row-0')),
        matching: find.text('1m'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('list-row-1')),
        matching: find.text('2. Cards'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('list-row-1')),
        matching: find.text('30s'),
      ),
      findsOneWidget,
    );

    controller.dispose();
    await store.close();
  });

  // 10. The current instance's row is highlighted: lightBlue label and a
  //     blue-tinted background distinct from the odd-row subtle tint.
  testWidgets('list_overlay_highlights_current', (tester) async {
    await pumpBoard(tester);
    controller.start();
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn-list')));
    await tester.pumpAndSettle();

    final label0 = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('list-row-0')),
        matching: find.text('1. break'),
      ),
    );
    expect(label0.style?.color, AppColors.lightBlue);

    final row0 = tester.widget<Container>(find.byKey(const Key('list-row-0')));
    final row1 = tester.widget<Container>(find.byKey(const Key('list-row-1')));
    expect(row0.color, AppColors.blue.withValues(alpha: 0.25));
    expect(row0.color, isNot(equals(row1.color)));

    controller.dispose();
    await store.close();
  });

  // 11. Tapping a row jumps the cursor there AND closes the overlay.
  testWidgets('list_overlay_jump_dispatches_and_closes', (tester) async {
    await pumpBoard(tester);
    controller.start();
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn-list')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('list-row-1')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.ordinal, 1);
    expect(find.byKey(const Key('list-overlay')), findsNothing);

    controller.dispose();
    await store.close();
  });

  // 12. Reset needs confirmation: cancel leaves the run untouched.
  testWidgets('reset_requires_confirmation', (tester) async {
    await pumpBoard(tester);
    controller.start();
    await tester.pump();

    await tester.tap(find.byKey(const Key('btn-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Reset timer?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dialog-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dialog-cancel')), findsNothing);
    expect(controller.snapshot.state, SessionState.running);

    controller.dispose();
    await store.close();
  });

  // 13. Confirming the reset dialog returns the session to notStarted.
  testWidgets('reset_confirms_and_resets', (tester) async {
    await pumpBoard(tester);
    controller.start();
    await tester.pump();

    await tester.tap(find.byKey(const Key('btn-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dialog-confirm')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.state, SessionState.notStarted);
    expect(controller.snapshot.ordinal, isNull);

    controller.dispose();
    await store.close();
  });

  // 14. Skip is disabled at notStarted; it advances from running, from
  //     paused (past the end → fresh notStarted), and from awaitingAdvance.
  testWidgets('skip_button_dispatches_per_state', (tester) async {
    await pumpBoard(tester);

    expect(
      tester.widget<IconButton>(find.byKey(const Key('btn-skip'))).onPressed,
      isNull,
    );

    controller.start();
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn-skip')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.running);
    expect(controller.snapshot.ordinal, 1);

    controller.pause();
    await tester.pump();
    expect(controller.snapshot.state, SessionState.paused);
    await tester.tap(find.byKey(const Key('btn-skip')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.notStarted); // past the end

    controller.start();
    await tester.pump();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    await tester.tap(find.byKey(const Key('btn-skip')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.running);
    expect(controller.snapshot.ordinal, 1);

    controller.dispose();
    await store.close();
  });

  // 15. Auto-finish last instance crossing → the fresh notStarted planned
  //     readout renders again immediately; no hold, no tap-to-continue.
  testWidgets('end_auto_finish_resets_immediately', (tester) async {
    controller.dispose();
    await store.close();
    await buildFixture(
      defs: [(id: 'x', name: 'lap', seconds: 5, autoFinish: true)],
    );

    await pumpBoard(tester);
    controller.start();
    await tester.pump();
    clock.current = clock.current.add(const Duration(seconds: 6));
    await controller.tick();
    await tester.pump();

    expect(controller.snapshot.state, SessionState.notStarted);
    // Planned readout of the fresh 5s total: 00 H 00 / 05.
    expect(find.text('00'), findsNWidgets(2));
    expect(find.text('H'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    expect(find.byKey(const Key('tap-to-continue')), findsNothing);

    controller.dispose();
    await store.close();
  });

  // 16. Manually-complete LAST instance holds at 00:00 + WAIT +
  //     tap-to-continue; tapping it advances past the end → notStarted.
  testWidgets('end_manual_hold_then_tap_resets', (tester) async {
    controller.dispose();
    await store.close();
    await buildFixture(
      defs: [(id: 'x', name: 'lap', seconds: 5, autoFinish: false)],
    );

    await pumpBoard(tester);
    controller.start();
    await tester.pump();
    clock.current = clock.current.add(const Duration(seconds: 6));
    await controller.tick();
    await tester.pump();

    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    expect(find.text('WAIT'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.byKey(const Key('tap-to-continue')), findsOneWidget);
    expect(find.byKey(const Key('caption')), findsNothing);

    await tester.tap(find.byKey(const Key('tap-to-continue')));
    await tester.pump();

    expect(controller.snapshot.state, SessionState.notStarted);
    expect(find.byKey(const Key('tap-to-continue')), findsNothing);

    controller.dispose();
    await store.close();
  });

  /// The dial painter's inputs: the tick ring maps the WHOLE timer as
  /// per-interval color segments (fractions of total duration).
  testWidgets('dial_ticks_map_whole_timer_by_interval_color', (tester) async {
    await buildFixture();
    await store.saveTree(
      controller.timer.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'x',
            timerId: controller.timer.id,
            name: 'warmup',
            color: '#ff00b1',
            durationSeconds: 60,
            autoFinish: true,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'y',
            timerId: controller.timer.id,
            name: 'run',
            color: '#4800ff',
            durationSeconds: 60,
            autoFinish: true,
          ),
        ),
      ]),
      eventKind: 'tree.save',
    );
    await controller.reload();
    await pumpBoard(tester);

    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byKey(const Key('dial')),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter as dynamic;
    expect(painter.segments.length, 2);
    expect(painter.segments[0].start, 0.0);
    expect(painter.segments[0].end, 0.5);
    expect(painter.segments[1].start, 0.5);
    expect(painter.segments[1].end, 1.0);
    expect((painter.segments[0].color as Color).toARGB32(), 0xFFFF00B1);
    expect((painter.segments[1].color as Color).toARGB32(), 0xFF4800FF);
    expect(painter.elapsed, 0.0); // notStarted: nothing dimmed yet

    controller.dispose();
    await store.close();
  });

  /// Progress spans the WHOLE timer: 30s into the 90s fixture = 1/3, not
  /// the old per-interval fraction.
  testWidgets('dial_progress_spans_whole_timer', (tester) async {
    await pumpBoard(tester);
    expect(controller.start(), isTrue);
    clock.current = clock.current.add(const Duration(seconds: 30));
    await controller.tick();
    await tester.pump();

    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byKey(const Key('dial')),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter as dynamic;
    expect(painter.elapsed, moreOrLessEquals(30 / 90, epsilon: 0.001));

    controller.dispose();
    await store.close();
  });
}

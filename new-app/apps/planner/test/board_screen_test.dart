import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/editor_screen.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Board screen widget tests (P3.1/P3.2 / v2 P2.3): the state-driven
/// readout, the tap and Space dispatch, caption visibility, the editor
/// route, the control row (adjust, reset, skip), the right-click jump and
/// Alt+↑/↓ jumps, and the end-of-timer affordances —
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
  // Keyboard navigation (acceptance): quick keys and dialog keys.
  testWidgets('keyboard_media_key_acts_like_space', (tester) async {
    await pumpBoard(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();
    expect(controller.snapshot.state, SessionState.running);
    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();
    expect(controller.snapshot.state, SessionState.paused);
    controller.dispose();
    await store.close();
  });

  testWidgets('keyboard_quick_keys_open_dialogs_and_act', (tester) async {
    await pumpBoard(tester);

    // Delete = the reset button — focus starts on CANCEL: Enter cancels.
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('Reset timer?'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Reset timer?'), findsNothing);
    expect(controller.snapshot.state, SessionState.notStarted);

    // Escape on the board = the timer editor.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editor-done')), findsOneWidget);
  });

  testWidgets('keyboard_reset_dialog_right_confirms', (tester) async {
    await pumpBoard(tester);
    expect(await controller.start(), isTrue);
    await tester.pump();

    // Delete opens the dialog; Right selects Reset; Enter resets the run.
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.snapshot.state, SessionState.notStarted);
  });

  testWidgets('keyboard_arrows_walk_control_buttons', (tester) async {
    await pumpBoard(tester);
    expect(await controller.start(), isTrue);
    await tester.pump();

    // Focus starts on the first cell (adjust time, tweaks #7): the row
    // is [adjust][reset][skip] (P2.3) — Right x2 lands on skip, Enter
    // advances the run (same as the button).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.snapshot.ordinal, 1); // skip advanced the run

    // Home jumps back to the first button; Enter opens the +/− time menu.
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adjust-modal')), findsOneWidget);
  });

  // v2 P2.3: Alt+Down/Up jumps between intervals — keyboard parity with
  // the right-click jump (the Tab-opened interval picker is gone).
  testWidgets('alt_down_up_jump_between_intervals', (tester) async {
    await pumpBoard(tester);
    expect(await controller.start(), isTrue);
    await tester.pump();

    // Alt+Down: the next occurrence, still running at the target.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(controller.snapshot.ordinal, 1);
    expect(controller.snapshot.state, SessionState.running);

    // Alt+Up: back to the first — a running jump keeps running.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(controller.snapshot.ordinal, 0);
    expect(controller.snapshot.state, SessionState.running);

    // At the first interval Alt+Up stays put — the key is still absorbed
    // (the button-walk model must not steal it).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(controller.snapshot.ordinal, 0);
    expect(controller.snapshot.state, SessionState.running);

    controller.dispose();
    await store.close();
  });

  testWidgets('board_renders_not_started_planned', (tester) async {
    await pumpBoard(tester);

    // Planned parts of 90s: ('00', '01', '30') in the 03H : 00M / 00 layout.
    expect(find.text('00'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    // The next-interval caption is retired (acceptance — the '>' skip
    // control replaced the MultiTimer-era advance hint).
    expect(find.text('1. break - 1m'), findsNothing);
    expect(find.text('PAUSED'), findsNothing);
    expect(find.text('WAIT'), findsNothing);

    controller.dispose();
    await store.close();
  });

  // 2. Running: hm total on top, big mm:ss, current label, next caption.
  testWidgets('board_renders_running', (tester) async {
    await pumpBoard(tester);
    expect(await controller.start(), isTrue);
    await tester.pump();

    expect(find.text('1m'), findsOneWidget); // totalRemaining 90s
    expect(find.text('01:00'), findsOneWidget); // current remaining 60s
    expect(find.text('1. break'), findsOneWidget);
    expect(find.text('2. Cards - 30s'), findsNothing); // caption retired
    expect(find.text('PAUSED'), findsNothing);
    expect(find.text('WAIT'), findsNothing);

    controller.dispose();
    await store.close();
  });

  // 3. Paused: the PAUSED chip joins the big line, which still shows the
  //    frozen remaining.
  testWidgets('board_renders_paused', (tester) async {
    await pumpBoard(tester);
    await controller.start();
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
    await controller.start();
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

  // 5. Readout taps dispatch the context action for each state in turn
  //    (P2.1: the dial is gone — its tap lives on the display).
  testWidgets('tap_dispatches_context_actions', (tester) async {
    await pumpBoard(tester);

    await tester.tap(find.byKey(const Key('readout')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.running);

    await tester.tap(find.byKey(const Key('readout')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.paused);

    await tester.tap(find.byKey(const Key('readout')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.running);

    controller.dispose();
    await store.close();
  });

  // 6. Space performs the same dispatch as a readout tap.
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

  // 8. Right-click on the readout opens the interval editor (P4.1).
  testWidgets('right_click_opens_editor_screen', (tester) async {
    await pumpBoard(tester);

    await tester.tap(
      find.byKey(const Key('readout')),
      buttons: kSecondaryMouseButton,
    );
    // The handler is async (loads the tree before pushing) — settle the
    // microtask and the route transition.
    await tester.pumpAndSettle();

    expect(find.byType(EditorScreen), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // ── v2 P2.3: row navigation (jump) ─────────────────────────

  // Right-clicking a row jumps DIRECTLY there: a running run keeps
  // running at the target occurrence (the first at or after the cursor),
  // with no confirmation step — the interval-picker overlay is gone.
  testWidgets('right_click_row_jumps_and_keeps_running', (tester) async {
    await pumpBoard(tester);
    expect(await controller.start(), isTrue);
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('row-b')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();

    expect(controller.snapshot.ordinal, 1);
    expect(controller.snapshot.state, SessionState.running);
    expect(find.byType(Dialog), findsNothing); // direct jump, no dialog

    controller.dispose();
    await store.close();
  });

  // Backward jump from a PAUSED run: a cursor past the row picks that
  // row's LAST occurrence; the run sits paused-ready at the target.
  testWidgets('right_click_row_jumps_backward_while_paused', (tester) async {
    await pumpBoard(tester);
    expect(await controller.start(), isTrue);
    await tester.pump();
    expect(controller.skipNext(), isTrue); // cursor → 'Cards' (ordinal 1)
    await tester.pump();
    controller.pause();
    await tester.pump();

    await tester.tap(
      find.byKey(const Key('row-a')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();

    expect(controller.snapshot.ordinal, 0);
    expect(controller.snapshot.state, SessionState.paused);
    expect(find.byType(Dialog), findsNothing);

    controller.dispose();
    await store.close();
  });

  // v2 P2.3: the interval-picker overlay is gone — no list button, the
  // control row is exactly [adjust][reset][skip], and Tab opens nothing.
  testWidgets('interval_picker_is_gone_and_tab_does_nothing', (tester) async {
    await pumpBoard(tester);

    expect(find.byKey(const Key('btn-list')), findsNothing);
    expect(find.byKey(const Key('list-overlay')), findsNothing);
    expect(
      [
        for (final w in tester.widgetList<IconButton>(
          find.descendant(
            of: find.byKey(const Key('control-row')),
            matching: find.byType(IconButton),
          ),
        ))
          w.key!,
      ],
      const [Key('btn-adjust'), Key('btn-reset'), Key('btn-skip')],
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byKey(const Key('list-overlay')), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(controller.snapshot.state, SessionState.notStarted);

    controller.dispose();
    await store.close();
  });

  // v2 P2.3 (short-list rule): a list that fits the viewport has
  // nothing to center — the auto-scroll leaves it parked at the top.
  testWidgets('short_list_does_not_scroll', (tester) async {
    await pumpBoard(tester); // 2-def fixture on the 800x600 test surface
    expect(await controller.start(), isTrue);
    await tester.pump();
    expect(controller.skipNext(), isTrue); // cursor → row b
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.maxScrollExtent, 0);
    expect(position.pixels, 0);

    controller.dispose();
    await store.close();
  });

  // 12. Reset needs confirmation: cancel leaves the run untouched.
  testWidgets('reset_requires_confirmation', (tester) async {
    await pumpBoard(tester);
    await controller.start();
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
    await controller.start();
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

    await controller.start();
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

    await controller.start();
    await tester.pump();
    clock.current = clock.current.add(const Duration(seconds: 60));
    await controller.tick();
    await tester.pump();
    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    // Tweaks #5: in limbo the skip button steps aside (the row shows the
    // limbo actions) — tap-to-continue completes the held interval instead.
    expect(find.byKey(const Key('btn-skip')), findsNothing);
    await tester.tap(find.byKey(const Key('tap-to-continue')));
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
    await controller.start();
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
    await controller.start();
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

  // Tweaks #5/#7: the control row is state-driven — adjust (+/- time) is
  // first on a live run; a manual hold switches the row to the limbo
  // actions (silence + adjust) and the abandon-run buttons step aside.
  testWidgets('tweaks_control_row_state_driven', (tester) async {
    await pumpBoard(tester);
    // notStarted: the adjust button is disabled (nothing to adjust).
    expect(tester.widget<IconButton>(find.byKey(const Key('btn-adjust'))).onPressed, isNull);
    await controller.start();
    await tester.pump();
    expect(tester.widget<IconButton>(find.byKey(const Key('btn-adjust'))).onPressed, isNotNull);
    expect(find.byKey(const Key('btn-list')), findsNothing); // P2.3: gone
    expect(find.byKey(const Key('btn-reset')), findsOneWidget);
    expect(find.byKey(const Key('btn-skip')), findsOneWidget);
    expect(
      [
        for (final w in tester.widgetList<IconButton>(
          find.descendant(
            of: find.byKey(const Key('control-row')),
            matching: find.byType(IconButton),
          ),
        ))
          w.key!,
      ],
      const [Key('btn-adjust'), Key('btn-reset'), Key('btn-skip')],
    );

    // The fixture's intervals are manually complete: the run lands in
    // limbo and the row switches.
    clock.current = clock.current.add(const Duration(seconds: 65));
    await controller.tick();
    await tester.pump();
    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    expect(find.byKey(const Key('btn-silence')), findsOneWidget);
    expect(find.byKey(const Key('btn-adjust')), findsOneWidget);
    // v2 P2.2: at a hold the second slot IS the decision — "not completed"
    // (the interval-list shortcut steps aside).
    expect(find.byKey(const Key('btn-not-completed')), findsOneWidget);
    expect(find.byKey(const Key('btn-list')), findsNothing);
    expect(find.byKey(const Key('btn-reset')), findsOneWidget); // kept
    expect(find.byKey(const Key('btn-skip')), findsNothing); // the hold
    // Slot contract: the shared buttons keep their spots — silence takes
    // skip's far-right slot in both modes.
    List<Key> rowKeys(WidgetTester t) => [
      for (final w in t.widgetList<IconButton>(
        find.descendant(
          of: find.byKey(const Key('control-row')),
          matching: find.byType(IconButton),
        ),
      ))
        w.key!,
    ];
    expect(rowKeys(tester), const [
      Key('btn-adjust'),
      Key('btn-not-completed'),
      Key('btn-reset'),
      Key('btn-silence'),
    ]);
    controller.dispose();
  });

  // Tweaks #7: the menu applies a signed delta to the current instance's
  // remaining for this run only.
  testWidgets('tweaks_adjust_menu_applies_delta', (tester) async {
    await pumpBoard(tester);
    await controller.start();
    await tester.pump();
    await tester.tap(find.byKey(const Key('btn-adjust')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // the route in
    expect(find.byKey(const Key('adjust-modal')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('adjust-min')), '05');
    await tester.tap(find.byKey(const Key('adjust-apply')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // the route out
    // +5 min on the 60s first instance.
    expect(controller.snapshot.remaining, const Duration(seconds: 360));
    controller.dispose();
  });

  // Tweaks #5: silence keeps the hold; the play button is what completes.
  testWidgets('tweaks_silence_keeps_limbo', (tester) async {
    await pumpBoard(tester);
    await controller.start();
    clock.current = clock.current.add(const Duration(seconds: 65));
    await controller.tick();
    await tester.pump();
    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    await tester.tap(find.byKey(const Key('btn-silence')));
    await tester.pump();
    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    controller.dispose();
  });

  // Tweaks #8 end-to-end (the user's exact flow): open the editor on a
  // RUNNING timer, hit Done — the run keeps going.
  testWidgets('tweaks_editor_done_keeps_the_run', (tester) async {
    await pumpBoard(tester);
    await controller.start();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // open editor
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // route in
    expect(find.byKey(const Key('editor-done')), findsOneWidget);
    await tester.tap(find.byKey(const Key('editor-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // route out
    expect(controller.snapshot.state, SessionState.running);
    controller.dispose();
  });
}

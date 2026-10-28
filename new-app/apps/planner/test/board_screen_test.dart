import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/editor_placeholder.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Board screen widget tests (P3.1): the state-driven readout, the tap and
/// Space dispatch, caption visibility, and the editor route — over a real
/// AppController on an in-memory drift store with recording adapters.
///
/// Fixture: TWO defs saved BEFORE init — 'break' 60s (manual) and 'Cards'
/// 30s (manual); totalPlanned = 90s. NOTE: 'break' is deliberately a MANUAL
/// (autoFinish=false) instance so its zero-crossing parks the session in
/// awaitingAdvance — test 4 asserts the WAIT chip right after +60s, which
/// the engine only produces for manually-complete instances.
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late AppController controller;

  setUp(() async {
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
            id: 'b',
            timerId: timer.id,
            name: 'Cards',
            color: '#0055ff',
            durationSeconds: 30,
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
  });

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
  //    chip; the caption still offers 'Cards'.
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
    expect(find.text('2. Cards - 30s'), findsOneWidget);
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

  // 8. Right-click on the dial opens the P4.1 editor placeholder.
  testWidgets('right_click_opens_editor_placeholder', (tester) async {
    await pumpBoard(tester);

    await tester.tap(
      find.byKey(const Key('dial')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle(); // settle the route transition

    expect(find.byType(EditorPlaceholderScreen), findsOneWidget);
    expect(find.byKey(const Key('editor-placeholder')), findsOneWidget);

    controller.dispose();
    await store.close();
  });
}

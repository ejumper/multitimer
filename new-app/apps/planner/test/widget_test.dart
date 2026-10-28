import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner/main.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

void main() {
  testWidgets('PlannerApp boots into the board screen', (tester) async {
    // Real in-memory store + recording adapters — the same wiring main.dart
    // performs, minus the plugins.
    final clock = FixedClock(DateTime.utc(2026, 3, 1, 8));
    final store = DriftStore(PlannerDb(NativeDatabase.memory()), clock);
    final controller = AppController(
      store: store,
      clock: clock,
      notifier: RecordingNotifier(),
      player: RecordingPlayer(),
      soundsDir: '/sounds',
      soundListing: () => const [],
    );
    await controller.init();
    await tester.pumpWidget(PlannerApp(controller: controller));

    expect(find.byType(BoardScreen), findsOneWidget);
    expect(find.byKey(const Key('dial')), findsOneWidget); // fresh session

    // Dispose in-body: flutter_test checks pending-timer invariants before
    // addTearDown runs, and the controller owns a 1 Hz ticker.
    controller.dispose();
    await store.close();
  });
}

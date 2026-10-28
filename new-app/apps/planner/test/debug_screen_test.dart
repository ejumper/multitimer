import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/debug_screen.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Temporary debug screen (P2.1): renders the snapshot and the run controls
/// against a real in-memory store with recording adapters.
void main() {
  testWidgets('debug_screen_renders_snapshot_and_controls', (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 3, 1, 8));
    final store = DriftStore(PlannerDb(NativeDatabase.memory()), clock);
    final controller = AppController(
      store: store,
      clock: clock,
      notifier: RecordingNotifier(),
      player: RecordingPlayer(),
      soundsDir: '/sounds',
      soundListing: () => const ['a.mp3'],
    );
    await controller.init();
    await tester.pumpWidget(MaterialApp(home: DebugScreen(controller)));

    // Snapshot readout (fresh session).
    expect(find.text('notStarted'), findsOneWidget);
    expect(find.text('<unnamed>'), findsOneWidget);
    // Run controls.
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    // Adapter smoke buttons.
    expect(find.text('Test notification'), findsOneWidget);
    expect(find.text('Test sound'), findsOneWidget);

    // Start is the only legal control from notStarted.
    ElevatedButton button(String label) => tester.widget<ElevatedButton>(
          find.ancestor(of: find.text(label), matching: find.byType(ElevatedButton)),
        );
    expect(button('Start').onPressed, isNotNull);
    expect(button('Pause').onPressed, isNull);

    // Dispose in-body: flutter_test checks pending-timer invariants before
    // addTearDown runs, and the controller owns a 1 Hz ticker.
    controller.dispose();
    await store.close();
  });
}

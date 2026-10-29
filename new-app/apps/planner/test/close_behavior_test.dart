import 'package:flutter_test/flutter_test.dart';
import 'package:planner/main.dart';
import 'package:planner_engine/planner_engine.dart';

/// The hybrid close policy (acceptance): closing the window hides to tray
/// while a run is live (its alerts must keep firing — D5), and quits when
/// idle.
void main() {
  test('close_hides_to_tray_only_during_a_live_run', () {
    expect(closeHidesToTray(SessionState.notStarted), isFalse);
    expect(closeHidesToTray(SessionState.running), isTrue);
    expect(closeHidesToTray(SessionState.paused), isTrue);
    expect(closeHidesToTray(SessionState.awaitingAdvance), isTrue);
  });
}

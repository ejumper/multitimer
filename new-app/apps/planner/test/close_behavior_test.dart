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

  // Tweaks #10: the notification's Continue advances ONLY while the run
  // is held at zero — a click racing an in-app advance is a no-op instead
  // of skipping another interval.
  test('continue_advances_only_while_awaiting', () {
    expect(continueAdvances(SessionState.awaitingAdvance), isTrue);
    expect(continueAdvances(SessionState.notStarted), isFalse);
    expect(continueAdvances(SessionState.running), isFalse);
    expect(continueAdvances(SessionState.paused), isFalse);
  });
}

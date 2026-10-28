import 'package:planner_engine/planner_engine.dart';
import 'package:test/test.dart';

/// Perf sanity (P-engine): flattening a 100+ instance tree and projecting
/// one session snapshot must stay far below the 10 ms bound — the projection
/// runs on the app's 1 Hz heartbeat, so it must never eat a frame budget.
/// Typical runtime is well under 1 ms; the bound has huge headroom and will
/// not flake. Local fixed clock / noop sink doubles keep this file free of
/// any store or wall-clock dependency.
void main() {
  test('flatten_and_snapshot_under_10ms_100_plus_instances', () {
    // 12 groups × 10 DefNodes, nested one level, repeatCount 1 each →
    // flatten yields 120 instances.
    final tree = IntervalTree([
      for (var g = 0; g < 12; g++)
        GroupNode(
          GroupDef(id: 'g$g', timerId: 'T', repeatCount: 1),
          [
            for (var d = 0; d < 10; d++)
              DefNode(
                IntervalDef(
                  id: 'g${g}_d$d',
                  timerId: 'T',
                  color: '#0055ff',
                  durationSeconds: 60,
                  autoFinish: true,
                ),
              ),
          ],
        ),
    ]);

    final clock = FixedClock(DateTime.utc(2026, 3, 1, 8));
    expect(flatten(tree), hasLength(120));

    final stopwatch = Stopwatch()..start();
    final instances = flatten(tree);
    final session = TimerSession(instances, clock: clock, sink: NoopSink());
    session.snapshot(clock.now());
    stopwatch.stop();

    expect(stopwatch.elapsedMicroseconds, lessThan(10000)); // < 10 ms
  });
}

/// Fixed test clock: the perf test only needs a stable instant to project at.
class FixedClock implements Clock {
  FixedClock(this.current);

  final DateTime current;

  @override
  DateTime now() => current;
}

/// Sink that swallows everything — the measurement is flatten + snapshot
/// cost, not consumption.
class NoopSink implements EventSink<InstanceEnded> {
  @override
  void emit(InstanceEnded event) {}
}

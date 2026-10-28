import 'package:planner_engine/planner_engine.dart';
import 'package:test/test.dart';

/// Placeholder contract test for the engine's `Clock` seam (P0.1).
///
/// The real engine (P1.x) receives a `Clock` via constructor injection and
/// computes all timer state from `clock.now()` — never `DateTime.now()`.
/// These tests pin down the minimal contract the engine relies on.
void main() {
  group('Clock', () {
    test('now() returns the injected instant for a fixed clock', () {
      final instant = DateTime.utc(2026, 10, 27, 12, 0, 0);
      final clock = _FixedClock(instant);

      expect(clock.now(), same(instant));
    });

    test('two clocks can disagree — time is a dependency, not a global', () {
      final early = _FixedClock(DateTime.utc(2026, 1, 1));
      final late = _FixedClock(DateTime.utc(2026, 12, 31));

      expect(late.now().isAfter(early.now()), isTrue);
    });

    test('now() returns a DateTime in the UTC-or-local iso8601 space', () {
      // The engine only ever compares/derives Durations between instants, so
      // any well-formed DateTime satisfies the contract.
      final clock = _FixedClock(DateTime.utc(2026, 10, 27));
      expect(clock.now(), isA<DateTime>());
      expect(clock.now().microsecondsSinceEpoch, greaterThan(0));
    });
  });
}

class _FixedClock implements Clock {
  _FixedClock(this._instant);

  final DateTime _instant;

  @override
  DateTime now() => _instant;
}

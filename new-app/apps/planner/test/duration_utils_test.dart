import 'package:flutter_test/flutter_test.dart';
import 'package:planner/duration_utils.dart';

/// Pure duration-box math (P4.3): the carry-up normalization table, the
/// 2-digit box sanitizer, and the split/normalize round trip — no widgets.
void main() {
  // Carry table: seconds roll into minutes (90s → +1m30), minutes into
  // hours (75m → +1h15, 3600s → 1h), 99h stays 99h (no cap), zero stays
  // zero, and an already-clean input passes through.
  final carryTable = <({int hours, int minutes, int seconds}), Duration>{
    (hours: 0, minutes: 10, seconds: 90): const Duration(
      minutes: 11,
      seconds: 30,
    ),
    (hours: 0, minutes: 75, seconds: 0): const Duration(hours: 1, minutes: 15),
    (hours: 0, minutes: 0, seconds: 3600): const Duration(hours: 1),
    (hours: 99, minutes: 0, seconds: 0): const Duration(hours: 99),
    (hours: 0, minutes: 0, seconds: 0): Duration.zero,
    (hours: 2, minutes: 3, seconds: 4): const Duration(
      hours: 2,
      minutes: 3,
      seconds: 4,
    ),
  };

  test('normalize_duration_carry_table', () {
    for (final entry in carryTable.entries) {
      final input = entry.key;
      expect(
        normalizeDuration(
          hours: input.hours,
          minutes: input.minutes,
          seconds: input.seconds,
        ),
        entry.value,
        reason: 'normalize(${input.hours}h ${input.minutes}m '
            '${input.seconds}s)',
      );
    }
  });

  // Digits only, truncated to the box width; junk and overflow drop out.
  test('sanitize_box_two_digit_limit', () {
    expect(sanitizeBox('123'), '12'); // 2-digit box cap
    expect(sanitizeBox('ab7'), '7'); // non-digits stripped
    expect(sanitizeBox(''), ''); // empty box stays empty
  });

  // split is the inverse of normalize for seeded boxes: the components are
  // the plain decomposition and re-normalizing rebuilds the same Duration.
  test('split_duration_round_trip', () {
    for (final input in carryTable.keys) {
      final normalized = normalizeDuration(
        hours: input.hours,
        minutes: input.minutes,
        seconds: input.seconds,
      );
      final parts = splitDuration(normalized);
      expect(parts.hours, normalized.inHours);
      expect(parts.minutes, normalized.inMinutes % 60);
      expect(parts.seconds, normalized.inSeconds % 60);
      expect(
        normalizeDuration(
          hours: parts.hours,
          minutes: parts.minutes,
          seconds: parts.seconds,
        ),
        normalized,
        reason: 'split→normalize round trip of $normalized',
      );
    }
  });
}

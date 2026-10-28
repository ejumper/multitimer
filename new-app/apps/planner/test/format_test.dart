import 'package:flutter_test/flutter_test.dart';
import 'package:planner/format.dart';

void main() {
  // 1. mm:ss — zero-padded, minutes unbounded, negative clamps to zero.
  test('format_mm_ss_pads_and_overflows', () {
    expect(formatMmSs(const Duration(hours: 3, minutes: 18, seconds: 59)), '198:59');
    expect(formatMmSs(const Duration(seconds: 59)), '00:59');
    expect(formatMmSs(const Duration(seconds: 65)), '01:05');
    expect(formatMmSs(Duration.zero), '00:00');
    expect(formatMmSs(const Duration(seconds: -5)), '00:00');
  });

  // 2. hm — each component iff > 0; zero renders as 0m.
  test('format_hm_shows_nonzero_components', () {
    expect(formatHm(const Duration(hours: 6, minutes: 44)), '6h 44m');
    expect(formatHm(const Duration(hours: 3)), '3h');
    expect(formatHm(const Duration(minutes: 44)), '44m');
    expect(formatHm(Duration.zero), '0m');
    expect(formatHm(const Duration(seconds: -5)), '0m');
  });

  // 3. h/m/s — each component iff > 0; zero renders as 0s.
  test('format_duration_shows_nonzero_components', () {
    expect(formatDuration(const Duration(minutes: 7, seconds: 30)), '7m 30s');
    expect(formatDuration(const Duration(seconds: 45)), '45s');
    expect(formatDuration(const Duration(hours: 1, minutes: 10)), '1h 10m');
    expect(formatDuration(Duration.zero), '0s');
    expect(formatDuration(const Duration(seconds: -5)), '0s');
  });

  // 4. Planned dial parts — each zero-padded to two digits.
  test('format_planned_parts', () {
    expect(formatPlannedParts(const Duration(hours: 3)), ('03', '00', '00'));
    expect(
      formatPlannedParts(const Duration(hours: 1, minutes: 5, seconds: 9)),
      ('01', '05', '09'),
    );
    expect(formatPlannedParts(const Duration(seconds: 45)), ('00', '00', '45'));
  });

  // 5. Instance labels — 0-based ordinal renders 1-based; null → Interval.
  test('format_instance_label', () {
    expect(formatInstanceLabel(0, 'break'), '1. break');
    expect(formatInstanceLabel(2, null), '3. Interval');
  });
}

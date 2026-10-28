/// Pure duration-box helpers for the interval editor's `hr`/`min`/`sec`
/// setter — plain int math over [Duration]; no Flutter (or I/O) imports.
library;

/// Combines the three box values into one [Duration], carrying overflow UP
/// the way the reference keypad does: seconds ≥ 60 roll into minutes and
/// minutes ≥ 60 into hours — (0,10,90) → 11m30s, (0,75,0) → 1h15m,
/// (0,0,3600) → 1h. There is NO upper cap: hours stay as typed, so 99h
/// remains 99h.
Duration normalizeDuration({
  required int hours,
  required int minutes,
  required int seconds,
}) => Duration(seconds: hours * 3600 + minutes * 60 + seconds);

/// Sanitizes one box's raw text as the user types: digits only, truncated
/// to the 2-digit box width (`'123'` → `'12'`, `'ab7'` → `'7'`,
/// `''` → `''`).
String sanitizeBox(String input) {
  final digits = input.replaceAll(RegExp('[^0-9]'), '');
  return digits.length > 2 ? digits.substring(0, 2) : digits;
}

/// Splits [d] back into box values — the inverse of [normalizeDuration],
/// used to seed the editor's boxes in edit mode. Plain decomposition, NO
/// 99-hour clamp: `hours = d.inHours`, while minutes/seconds are the
/// remainders within their own hour/minute.
({int hours, int minutes, int seconds}) splitDuration(Duration d) => (
  hours: d.inHours,
  minutes: d.inMinutes % 60,
  seconds: d.inSeconds % 60,
);

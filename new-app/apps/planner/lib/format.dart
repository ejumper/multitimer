/// Pure formatting helpers for the board readout — defined once here and
/// shared by the dial, the run readout, and the next-interval caption.
///
/// Every helper clamps negative durations to zero: a backwards clock step
/// must never render as `-01:05` on the board.
library;

/// `mm:ss` for the big dial line — minutes zero-padded to at least two
/// digits but unbounded above (3h18m59s → `198:59`), seconds zero-padded
/// to two (59s → `00:59`). Negative → `00:00`.
String formatMmSs(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  final minutes = clamped.inMinutes.toString().padLeft(2, '0');
  final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Compact `h`/`m` total-remaining line — each component shown iff > 0 and
/// joined with a space (6h44m → `6h 44m`, 3h → `3h`, 44m → `44m`); zero →
/// `0m`. Seconds are intentionally dropped: this line is a rough "how much
/// life is left" readout above the precise dial line.
String formatHm(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  final parts = <String>[
    if (clamped.inHours > 0) '${clamped.inHours}h',
    if (clamped.inMinutes % 60 > 0) '${clamped.inMinutes % 60}m',
  ];
  return parts.isEmpty ? '0m' : parts.join(' ');
}

/// Verbose `h`/`m`/`s` duration for caption texts — each component shown
/// iff > 0 and joined with a space (7m30s → `7m 30s`, 45s → `45s`, 1h10m →
/// `1h 10m`); zero → `0s`. Unlike [formatHm] this keeps seconds: captions
/// quote authored interval durations exactly.
String formatDuration(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  final parts = <String>[
    if (clamped.inHours > 0) '${clamped.inHours}h',
    if (clamped.inMinutes % 60 > 0) '${clamped.inMinutes % 60}m',
    if (clamped.inSeconds % 60 > 0) '${clamped.inSeconds % 60}s',
  ];
  return parts.isEmpty ? '0s' : parts.join(' ');
}

/// The not-started planned readout as three zero-padded two-digit parts
/// `(hours, minutes, seconds)` for the `03H : 00M / 00` dial layout
/// (3h → `('03','00','00')`, 1h5m9s → `('01','05','09')`). Hours are
/// padded but unbounded above.
(String, String, String) formatPlannedParts(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  final hours = clamped.inHours.toString().padLeft(2, '0');
  final minutes = (clamped.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');
  return (hours, minutes, seconds);
}

/// Human interval label from the engine's 0-based [ordinal] — the board
/// shows 1-based positions (`(0,'break')` → `1. break`); unnamed instances
/// fall back to `Interval` (`(2,null)` → `3. Interval`).
String formatInstanceLabel(int ordinal, String? name) =>
    '${ordinal + 1}. ${name ?? 'Interval'}';

/// Append-only change log entry (D4: cheap insurance for future sync — sync
/// itself is NOT a v1 feature). Every mutation appends one event; terminal
/// state entries (done|cut|skipped|moved) land here from P1.4 on.
library;

class EventLogEntry {
  const EventLogEntry({
    required this.id,
    required this.seq,
    required this.timestampMs,
    required this.kind,
    required this.payloadJson,
  });

  /// UUIDv4 string.
  final String id;

  /// Monotonic insertion counter — the authoritative event order.
  final int seq;

  /// Epoch milliseconds, from the injected [Clock] — never DateTime.now().
  final int timestampMs;

  /// Dotted op kind, e.g. `board.create`, `tree.group`, `run.terminal` (P1.4).
  final String kind;

  /// JSON-encoded op payload (parameters of the mutation).
  final String payloadJson;

  @override
  String toString() => 'EventLogEntry($id, $timestampMs, $kind, $payloadJson)';
}

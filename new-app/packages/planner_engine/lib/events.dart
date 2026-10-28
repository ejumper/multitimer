/// Injected event sink (CONVENTIONS §2): the engine emits; the app decides
/// what emitting means (sound, notification, UI update, log line).
///
/// Clock lives in `clock.dart`; both are constructor-injected everywhere.
library;

abstract interface class EventSink<E> {
  /// Emit one event. Implementations must not throw into engine logic.
  void emit(E event);
}

/// How an instance ended (project vocabulary; logged from day one).
enum TerminalState {
  /// Reached zero (ran its course) or user moved past it at zero.
  done,

  /// Ended early by a wall — unused in v1 flows (enum is groundwork).
  cut,

  /// Ended before zero (skip, jump-away, jump-over, or reset).
  skipped,

  /// Relocated elsewhere — unused in v1 flows (enum is groundwork).
  moved,
}

/// Emitted exactly once when an instance's run occurrence ends.
class InstanceEnded {
  const InstanceEnded({
    required this.ordinal,
    required this.defId,
    required this.terminal,
    required this.endedAt,
  });

  /// Ordinal of the ended instance.
  final int ordinal;

  /// UUIDv4 of the authored def the instance came from.
  final String defId;

  /// How the instance ended.
  final TerminalState terminal;

  /// The true computed end moment, NOT the settle time.
  final DateTime endedAt;
}

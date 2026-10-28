/// Injected event sink (CONVENTIONS §2): the engine emits; the app decides
/// what emitting means (sound, notification, UI update, log line).
///
/// Clock lives in `clock.dart`; both are constructor-injected everywhere.
library;

abstract interface class EventSink<E> {
  /// Emit one event. Implementations must not throw into engine logic.
  void emit(E event);
}

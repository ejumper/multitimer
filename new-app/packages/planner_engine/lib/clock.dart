/// Source of the current instant, injected into the engine.
///
/// The engine never calls `DateTime.now()` and never touches the OS: all
/// timer state is derived from `clock.now()` (wall-clock anchors), which
/// makes the whole engine testable on a virtual clock (CONVENTIONS §2).
abstract interface class Clock {
  /// The current instant.
  DateTime now();
}

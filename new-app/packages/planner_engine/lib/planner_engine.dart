/// Pure-Dart engine for Planner: interval-timer data model, execution state
/// machine, schedule projection, and persistence interfaces.
///
/// No Flutter imports, no `dart:io`, no `DateTime.now()` — the app injects a
/// [Clock], storage, and event sinks (CONVENTIONS §2).
library;

export 'clock.dart';

import 'package:planner_engine/planner_engine.dart';

/// Wall-clock [Clock] for the app; the engine only ever reads time through
/// the injected instance (engine never calls `DateTime.now()` itself).
class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now();
}

/// Pure-Dart engine for Planner: interval-timer data model, execution state
/// machine, schedule projection, and persistence interfaces.
///
/// No Flutter imports, no `DateTime.now()` — the app injects a [Clock],
/// storage, and event sinks (CONVENTIONS §2). `dart:io` appears only inside
/// `storage/impl/` (the on-disk database opener), an exception documented in
/// the purity test.
library;

export 'clock.dart';
export 'events.dart';
export 'model/entities.dart';
export 'model/event_log.dart';
export 'model/group_def.dart';
export 'model/interval_def.dart';
export 'model/tree.dart';
export 'storage/drift_store.dart';
export 'storage/impl/db_opener.dart';
export 'storage/store.dart';
export 'uuid.dart';

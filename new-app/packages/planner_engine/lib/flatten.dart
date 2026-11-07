/// Schedule projection: compiles a nested [IntervalTree] into the flat
/// playback schedule — a list of [IntervalInstance]s, one per played
/// occurrence.
///
/// Complexity is linear in the output size: every tree node contributes
/// exactly one instance per pass it plays, and passes multiply down the
/// nesting (a group with repeat N emits its children's expansion N times).
///
/// Instances SNAPSHOT their def's values (name, color, durationSeconds,
/// autoFinish, endAlertSoundFile) at flatten time; later edits to the
/// authored [IntervalDef] never mutate already-flattened instances.
library;

import 'model/interval_def.dart';
import 'model/tree.dart';

/// One played occurrence of an authored interval — a flattened, immutable
/// value. [ordinal] is the 0-based position in the flattened list.
class IntervalInstance {
  const IntervalInstance({
    required this.ordinal,
    required this.defId,
    required this.name,
    required this.color,
    required this.durationSeconds,
    required this.autoFinish,
    required this.endAlertSoundFile,
    this.completed = false,
    this.triggerTimeSeconds,
  });

  /// 0-based position in the flattened list.
  final int ordinal;

  /// UUIDv4 of the authored [IntervalDef] this instance came from.
  final String defId;

  /// Snapshot of [IntervalDef.name]; null = unnamed.
  final String? name;

  /// Snapshot of [IntervalDef.color].
  final String color;

  /// Snapshot of [IntervalDef.durationSeconds]; null = Open (no duration —
  /// plays as a zero-length manual interval: instant, alert, hold).
  final int? durationSeconds;

  /// Snapshot of [IntervalDef.autoFinish] — the finish method: true =
  /// auto-finish, false = manually complete.
  final bool autoFinish;

  /// Snapshot of [IntervalDef.endAlertSoundFile]; null = no end alert.
  final String? endAlertSoundFile;

  /// Snapshot of [IntervalDef.completed] (the completion mark at flatten
  /// time; the session re-keys live marks by defId).
  final bool completed;

  /// Snapshot of [IntervalDef.triggerTimeSeconds]; null = order-triggered,
  /// non-null = a wall firing at this time-of-day (seconds since midnight).
  final int? triggerTimeSeconds;

  /// True for Open instances (no duration).
  bool get isOpen => durationSeconds == null;

  /// True for date-triggered (wall) instances.
  bool get isDated => triggerTimeSeconds != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntervalInstance &&
          other.ordinal == ordinal &&
          other.defId == defId &&
          other.name == name &&
          other.color == color &&
          other.durationSeconds == durationSeconds &&
          other.autoFinish == autoFinish &&
          other.endAlertSoundFile == endAlertSoundFile &&
          other.completed == completed &&
          other.triggerTimeSeconds == triggerTimeSeconds;

  @override
  int get hashCode => Object.hash(
    ordinal,
    defId,
    name,
    color,
    durationSeconds,
    autoFinish,
    endAlertSoundFile,
    completed,
    triggerTimeSeconds,
  );

  @override
  String toString() =>
      'IntervalInstance(#$ordinal, def=$defId, ${name ?? '<unnamed>'}, '
      'color=$color, ${durationSeconds == null ? 'open' : '${durationSeconds}s'}, '
      'autoFinish=$autoFinish, alert=${endAlertSoundFile ?? 'none'}, '
      'completed=$completed, at=${triggerTimeSeconds ?? 'order'})';
}

/// Expands [tree] depth-first into the flat playback schedule. Every
/// [DefNode] emits one instance (values snapshotted from its [IntervalDef]);
/// every [GroupNode] with repeatCount = N emits its children's expansion N
/// times back-to-back (N is total passes; nesting is uncapped, so a group
/// repeats within each pass of an enclosing group). Ordinals run 0..n-1 in
/// output order. An empty tree yields an empty list.
List<IntervalInstance> flatten(IntervalTree tree) {
  final out = <IntervalInstance>[];
  void walk(List<IntervalNode> nodes) {
    for (final node in nodes) {
      switch (node) {
        case DefNode(:final def):
          out.add(
            IntervalInstance(
              ordinal: out.length,
              defId: def.id,
              name: def.name,
              color: def.color,
              durationSeconds: def.durationSeconds,
              autoFinish: def.autoFinish,
              endAlertSoundFile: def.endAlertSoundFile,
              completed: def.completed,
              triggerTimeSeconds: def.triggerTimeSeconds,
            ),
          );
        case GroupNode(:final group, :final children):
          for (var pass = 0; pass < group.repeatCount; pass++) {
            walk(children);
          }
      }
    }
  }

  walk(tree.roots);
  return out;
}

/// Sum of all instances' [IntervalInstance.durationSeconds] (Open intervals
/// contribute nothing); empty input → [Duration.zero]. With Open items this
/// total is only the *known* part — pair it with [openCount] for display.
Duration totalPlanned(List<IntervalInstance> instances) => Duration(
  seconds: instances.fold<int>(
    0,
    (sum, i) => sum + (i.durationSeconds ?? 0),
  ),
);

/// How many instances are Open (no duration) — the "+ open" part a planned
/// total cannot express.
int openCount(List<IntervalInstance> instances) =>
    instances.where((i) => i.durationSeconds == null).length;

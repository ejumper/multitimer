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
  });

  /// 0-based position in the flattened list.
  final int ordinal;

  /// UUIDv4 of the authored [IntervalDef] this instance came from.
  final String defId;

  /// Snapshot of [IntervalDef.name]; null = unnamed.
  final String? name;

  /// Snapshot of [IntervalDef.color].
  final String color;

  /// Snapshot of [IntervalDef.durationSeconds].
  final int durationSeconds;

  /// Snapshot of [IntervalDef.autoFinish] — the finish method: true =
  /// auto-finish, false = manually complete.
  final bool autoFinish;

  /// Snapshot of [IntervalDef.endAlertSoundFile]; null = no end alert.
  final String? endAlertSoundFile;

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
          other.endAlertSoundFile == endAlertSoundFile;

  @override
  int get hashCode => Object.hash(
    ordinal,
    defId,
    name,
    color,
    durationSeconds,
    autoFinish,
    endAlertSoundFile,
  );

  @override
  String toString() =>
      'IntervalInstance(#$ordinal, def=$defId, ${name ?? '<unnamed>'}, '
      'color=$color, ${durationSeconds}s, autoFinish=$autoFinish, '
      'alert=${endAlertSoundFile ?? 'none'})';
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

/// Sum of all instances' [IntervalInstance.durationSeconds]; empty input →
/// [Duration.zero].
Duration totalPlanned(List<IntervalInstance> instances) => Duration(
  seconds: instances.fold<int>(0, (sum, i) => sum + i.durationSeconds),
);

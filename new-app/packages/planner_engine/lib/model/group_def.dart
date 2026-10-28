/// A group: a repeat bracket over one or more consecutive intervals
/// (CONVENTIONS §1: single-interval groups ARE allowed; nesting uncapped;
/// [repeatCount] N = total passes, 2 = runs twice).
///
/// Position within the tree (parent + order) is the storage encoding of
/// `parentGroupId` / `orderIndex` columns — the domain model carries it as
/// tree structure instead (see `tree.dart`).
library;

class GroupDef {
  const GroupDef({
    required this.id,
    required this.timerId,
    required this.repeatCount,
  }) : assert(repeatCount >= 1, 'repeatCount is total passes and must be >= 1');

  /// UUIDv4 string.
  final String id;
  final String timerId;

  /// Total number of passes (1 = play once).
  final int repeatCount;

  @override
  String toString() => 'GroupDef($id, repeat=$repeatCount)';
}

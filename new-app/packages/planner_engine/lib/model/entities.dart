/// Core entities: boards and interval timers.
///
/// Pure Dart — no Flutter, no dart:io (CONVENTIONS §2). Persistence shape is
/// mirrored by drift tables in `../storage/`.
library;

/// A board: the top-level workspace container. v1 shows a single board, but
/// boards are ordinary entities (no singletons).
class Board {
  const Board({required this.id, required this.name});

  /// UUIDv4 string.
  final String id;
  final String name;

  Board copyWith({String? name}) => Board(id: id, name: name ?? this.name);

  @override
  String toString() => 'Board($id, $name)';
}

/// An interval timer living on a board. One per board in v1, modeled 1:N.
///
/// v2 (P3.2): a timer IS a **plan** (CONVENTIONS §1) — the Library groups
/// the board's plans into [folderId] folders (null = the library root),
/// ordered by [sortIndex] ascending within their folder (new plans land on
/// top with a smaller index). [createdAt]/[updatedAt] are the Library row's
/// date stamps: epoch milliseconds of creation and of the last AUTHORED
/// change (creation, rename, tree edit). Completion marks (`run.mark`) are
/// execution, not authoring, and never touch [updatedAt]. `0` = a row that
/// predates schema v3 with an unknown origin.
///
/// P4 adds day provenance (`dayDate`/`originPlanId`) on top of this.
class IntervalTimer {
  const IntervalTimer({
    required this.id,
    required this.boardId,
    required this.name,
    required this.color,
    this.folderId,
    this.sortIndex = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  /// UUIDv4 string.
  final String id;
  final String boardId;

  final String name;

  /// Hex color string from the v1 preset swatches (D11), e.g. `#0055ff`.
  final String color;

  /// Library folder placement (null = the library root).
  final String? folderId;

  /// Position within the folder's ordered plan list.
  final int sortIndex;

  /// Created stamp, epoch milliseconds.
  final int createdAt;

  /// Last-authored-change stamp, epoch milliseconds.
  final int updatedAt;

  IntervalTimer copyWith({String? name, String? color}) => IntervalTimer(
    id: id,
    boardId: boardId,
    name: name ?? this.name,
    color: color ?? this.color,
    folderId: folderId,
    sortIndex: sortIndex,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  String toString() =>
      'IntervalTimer($id, board=$boardId, $name, $color, '
      'folder=$folderId, sort=$sortIndex)';
}

/// A Library folder (v2 P3.2): organization for plans — "a folder is just
/// organization; a 'template' is a folder" (CONVENTIONS §1). Root = no
/// folder: folder-less plans live directly in the Library.
class Folder {
  const Folder({required this.id, required this.name});

  /// UUIDv4 string.
  final String id;
  final String name;

  Folder copyWith({String? name}) => Folder(id: id, name: name ?? this.name);

  @override
  String toString() => 'Folder($id, $name)';
}

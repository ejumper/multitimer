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
class IntervalTimer {
  const IntervalTimer({
    required this.id,
    required this.boardId,
    required this.name,
    required this.color,
  });

  /// UUIDv4 string.
  final String id;
  final String boardId;

  final String name;

  /// Hex color string from the v1 preset swatches (D11), e.g. `#0055ff`.
  final String color;

  IntervalTimer copyWith({String? name, String? color}) => IntervalTimer(
    id: id,
    boardId: boardId,
    name: name ?? this.name,
    color: color ?? this.color,
  );

  @override
  String toString() => 'IntervalTimer($id, board=$boardId, $name, $color)';
}

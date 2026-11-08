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

/// The kinds of default rule a library plan can hold (v2 P3.4 — the
/// outline's template rules). Wire values are the TEXT names stored in
/// `default_rules.kind`; drift's `textEnum` breaks codegen (BLOCKERS #2),
/// so [DriftStore] maps these by name in both directions.
enum DefaultRuleKind {
  /// The plan's GLOBAL default: it claims every day no other rule wins.
  globalDefault('default'),

  /// A claim on a day of the week — [DefaultRule.value] 1–7 (Monday=1)
  /// while repeating, the concrete date otherwise (see [DefaultRule.value]).
  weekday('weekday'),

  /// A claim on a day of the month — [DefaultRule.value] 1–31 while
  /// repeating, the concrete date otherwise.
  monthday('monthday'),

  /// A claim on ONE specific date ([DefaultRule.value] as YYYYMMDD).
  date('date');

  const DefaultRuleKind(this.wireName);

  /// The exact TEXT stored in `default_rules.kind`.
  final String wireName;

  /// Maps a stored TEXT back to its kind — unknown values are corrupt data
  /// and throw ([DriftStore] reads through this).
  static DefaultRuleKind fromWireName(String name) {
    for (final kind in values) {
      if (kind.wireName == name) return kind;
    }
    throw StateError('unknown default rule kind: $name');
  }
}

/// A default rule (v2 P3.4): a library plan's claim on calendar days,
/// resolved by [resolvePlanFor] into the plan a placeholder day renders
/// (P4.1). One plan may hold several rules; several plans may compete for
/// the same day.
///
/// [value] depends on kind AND repeat:
/// - `globalDefault`: null.
/// - `weekday`/`monthday` with `repeat == true`: 1–7 (Monday=1) / 1–31.
/// - `weekday`/`monthday` with `repeat == false`: the ONE-OFF date the
///   rule claims, as the local day `YYYYMMDD` — "the default for this
///   Tuesday" (repeat off) means exactly that date, so the picked day has
///   to be carried in full (P3.4's repeat toggle: same day every week /
///   month, off = that one date).
/// - `date`: the local day as `YYYYMMDD`.
///
/// `repeat` is only read for `weekday`/`monthday` (the outline's "same day
/// every week/month" toggle); `date`/`globalDefault` rules ignore it.
class DefaultRule {
  const DefaultRule({
    required this.id,
    required this.timerId,
    required this.kind,
    this.value,
    this.repeat = false,
  });

  /// UUIDv4 string.
  final String id;

  /// The claiming plan (a timer id).
  final String timerId;
  final DefaultRuleKind kind;
  final int? value;
  final bool repeat;

  @override
  String toString() =>
      'DefaultRule($id, timer=$timerId, ${kind.wireName}, '
      'value=$value, repeat=$repeat)';
}

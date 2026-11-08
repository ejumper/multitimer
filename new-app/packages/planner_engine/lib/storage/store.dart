/// The persistence contract the app binds to (CONVENTIONS §2: injected, never
/// reached around). The drift implementation ([DriftStore]) lives beside this
/// interface in the engine package but takes an injected database executor —
/// the app constructs it with the XDG data-dir path (P2.1).
///
/// Every mutation appends one event to the change log (D4) inside the same
/// transaction. Higher-level tree ops ([groupNodes], [duplicateNodes], …)
/// load → transform ([IntervalTree] ops) → save, so their semantics are
/// defined once, in the domain.
library;

import '../model/entities.dart';
import '../model/event_log.dart';
import '../model/tree.dart';

abstract interface class Store {
  // ── boards ──────────────────────────────────────────────────────────────
  Future<List<Board>> allBoards();
  Future<Board> createBoard(String name);
  Future<void> renameBoard(String id, String name);
  Future<void> deleteBoard(String id);

  // ── interval timers ─────────────────────────────────────────────────────
  Future<List<IntervalTimer>> timersInBoard(String boardId);

  /// Creates a plan (timer). It lands on TOP of [folderId]'s ordered plan
  /// list (the "new list" rule, P3.2; null = the library root) and is
  /// stamped created/modified at the injected clock's now.
  Future<IntervalTimer> createTimer({
    required String boardId,
    required String name,
    required String color,
    String? folderId,
  });
  Future<void> updateTimer(String id, {String? name, String? color});
  Future<void> deleteTimer(String id);

  // ── library folders (v2 P3.2) ──────────────────────────────────────────
  /// All folders in display order (creation order).
  Future<List<Folder>> allFolders();
  Future<Folder> createFolder(String name);
  Future<void> renameFolder(String id, String name);

  /// Deletes the folder AND every plan inside it (the confirm dialog names
  /// the plan count; folder-less plans at the root are untouched).
  Future<void> deleteFolder(String id);

  /// Reorders a plan within/between folders: [toFolderId] null = the
  /// library root; [toIndex] is the position within the target folder's
  /// ordered plan list (clamped). Both affected folders' children are
  /// renumbered densely (0..n-1).
  Future<void> moveTimer({
    required String timerId,
    required String? toFolderId,
    required int toIndex,
  });

  // ── interval tree ───────────────────────────────────────────────────────
  Future<IntervalTree> loadTree(String timerId);

  /// Persists [tree] as the timer's whole definition (transactional) and
  /// appends an event [eventKind] with [eventPayload]. Tree ops below use
  /// this with their own kinds. Also bumps the plan's modified stamp —
  /// EXCEPT for `run.mark` writes (completion marks are execution, not
  /// authoring — the Library row's date must not churn while a list is
  /// being used).
  Future<void> saveTree(
    String timerId,
    IntervalTree tree, {
    required String eventKind,
    Map<String, Object?> eventPayload = const {},
  });

  Future<IntervalTree> groupNodes({
    required String timerId,
    required List<String> nodeIds,
    int repeatCount = 1,
  });
  Future<IntervalTree> ungroupNode({
    required String timerId,
    required String groupId,
  });
  Future<IntervalTree> duplicateNodes({
    required String timerId,
    required List<String> nodeIds,
  });
  Future<IntervalTree> deleteNodes({
    required String timerId,
    required List<String> nodeIds,
  });
  Future<IntervalTree> moveNode({
    required String timerId,
    required String nodeId,
    required String? newParentGroupId,
    required int newIndex,
  });

  // ── default rules (v2 P3.4) ────────────────────────────────────────────
  /// The plan's default rules in creation order (the menu lists them
  /// oldest first; resolution itself is order-independent — see
  /// `resolvePlanFor`).
  Future<List<DefaultRule>> rulesFor(String timerId);

  /// Adds a default rule for [timerId]. IDEMPOTENT: an identical rule
  /// (same timer, kind, value, and repeat) already present is returned
  /// unchanged — no second row, no change-log event. Throws [StateError]
  /// when [value] is malformed for [kind] (null on a non-default rule,
  /// weekday outside 1–7 / monthday outside 1–31 while repeating, a
  /// one-off weekday/monthday/date value that is no YYYYMMDD day).
  Future<DefaultRule> addRule({
    required String timerId,
    required DefaultRuleKind kind,
    int? value,
    bool repeat = false,
  });

  /// Removes the rule — throws [StateError] when [ruleId] is unknown
  /// (missing-row ops throw, like renameBoard/renameFolder).
  Future<void> removeRule(String ruleId);

  // ── days (v2 P4.1) ────────────────────────────────────────────────────
  /// The day's EXPLICIT plan reference (the `days` row's `planTimerId`),
  /// or null when the day has none configured. READ-ONLY: rules are not
  /// consulted and no row is ever written.
  Future<String?> dayPlanId(DateTime date);

  /// Pins [date] to [timerId] (null clears the pin back to unresolved —
  /// the row's `planTimerId` becomes NULL). The pin does not validate
  /// that the timer exists; resolution simply reads it back. Appends one
  /// `day.setPlan` change-log event.
  Future<void> setDayPlan(DateTime date, String? timerId);

  /// The plan [date] RENDERS: the explicit pin when set, else the winning
  /// default rule (the pure `resolvePlanFor` over ALL plans' rules —
  /// date > monthday > weekday > global default). Null when nothing
  /// claims the day.
  ///
  /// READ-ONLY — placeholder reads (board render, calendar counts) never
  /// materialize and never write rows.
  Future<String?> resolveDayPlan(DateTime date);

  /// The P4.1 lazy fork: creates [date]'s OWN timer — same board/name/
  /// color as the resolved plan, `folderId` null, `dayDate` = the day,
  /// `originPlanId` = the source plan — copies the source's tree AS IT
  /// STANDS through `IntervalTree.copiedToTimer` (fresh ids, completion
  /// marks cleared), points the day's row at the copy, and returns its id.
  ///
  /// IDEMPOTENT (materialized exactly once): a day already pointing at
  /// its own timer (`dayDate` == the day) returns that id untouched — no
  /// second copy, no second `day.materialize` event. Returns null when
  /// nothing claims the day (no pin, no rule) — no rows are written.
  Future<String?> materializeDay(DateTime date);

  /// How many AUTHORED intervals (tree `DefNode`s — group repeats are
  /// not expanded) the day's resolved plan has: `resolveDayPlan` + a tree
  /// read-through, with NO materialization (a count is a read; 0 when
  /// nothing claims the day).
  Future<int> dayItemCount(DateTime date);

  // ── change log ──────────────────────────────────────────────────────────
  /// All events, oldest first (insertion order).
  Future<List<EventLogEntry>> events();

  /// Appends one change-log event with a CALLER-supplied timestamp (used for
  /// run-log entries whose time is the instance's computed end moment, which
  /// may differ from wall-clock at write time).
  Future<void> appendEvent({
    required String kind,
    required int timestampMs,
    Map<String, Object?> payload = const {},
  });

  Future<void> close();
}

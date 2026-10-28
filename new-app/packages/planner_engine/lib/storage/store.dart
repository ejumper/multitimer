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
  Future<IntervalTimer> createTimer({
    required String boardId,
    required String name,
    required String color,
  });
  Future<void> updateTimer(String id, {String? name, String? color});
  Future<void> deleteTimer(String id);

  // ── interval tree ───────────────────────────────────────────────────────
  Future<IntervalTree> loadTree(String timerId);

  /// Persists [tree] as the timer's whole definition (transactional) and
  /// appends an event [eventKind] with [eventPayload]. Tree ops below use
  /// this with their own kinds.
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

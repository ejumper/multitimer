import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:planner_engine/planner_engine.dart';

import 'adapters/ports.dart';
import 'alert_handler.dart';

/// The app state seam: owns the persisted board/timer definitions plus the
/// in-memory run session over them, and renders nothing itself.
///
/// Run state is deliberately NEVER persisted: the [TimerSession] lives in
/// memory only, and every launch starts fresh at [SessionState.notStarted]
/// over the persisted definitions (the change log keeps the run history).
///
/// Timing derives from the injected [Clock] via a 1 Hz ticker calling
/// [tick]; intent methods are thin forwards onto the session — each settles
/// internally at `clock.now()`, notifies listeners synchronously, and lets
/// the next [tick] flush the queued run-log entries to the store.
class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    required this.clock,
    required this.notifier,
    required this.player,
    required this.soundsDir,
    required this.soundListing,
  });

  final Store store;
  final Clock clock;
  final Notifier notifier;
  final SoundPlayer player;
  final String soundsDir;

  /// Rescan-on-demand file-name listing of the alert-sounds directory.
  final List<String> Function() soundListing;

  late final Board board;
  // Not final: [reload] re-fetches the entity so name/color edits apply
  // without an app restart.
  late IntervalTimer timer;

  /// The calendar day this controller is bound to (P4.1), null for an
  /// ordinary plan/boot binding. Set by [init]; while set, every WRITE
  /// path materializes the day's own copy first
  /// ([_ensureDayMaterialized]) while every read goes through
  /// `resolveDayPlan` and writes nothing.
  DateTime? dayDate;

  /// Whether [dayDate]'s own copy has been materialized AND this
  /// controller rebinds to it — set once [_ensureDayMaterialized] has
  /// forked (or found) the day's timer.
  bool _dayMaterialized = false;

  /// The timer's authored interval TREE — the board's list view renders
  /// its rows (P2.1) over the same definitions as [instances] (the
  /// flattened run). Kept in sync by [_buildSession] and [applyTreeEdit].
  late IntervalTree tree;

  late List<IntervalInstance> instances;
  late RunEventProcessor processor;
  late TimerSession session;

  /// The alert sink of the CURRENT session ([_buildSession] rebuilds both
  /// together) — held so the advance actions can cut a looping alert.
  late AlertHandler alerts;

  Timer? _ticker;

  /// The session's projection at [clock.now].
  TimerSnapshot get snapshot => session.snapshot(clock.now());

  bool get isRunning => snapshot.state == SessionState.running;

  /// Boots from the store: first board (creating `My Board` when empty),
  /// then its first interval timer (creating `Interval timer` when empty),
  /// loads the timer's tree into a fresh session, and starts the 1 Hz
  /// ticker.
  ///
  /// [timerId] binds the controller to ONE timer (P3.2's plan board): the
  /// board containing that timer owns the controller instead of the boot
  /// default. An unknown id falls back to the default boot behavior.
  ///
  /// [dayDate] binds the controller to a CALENDAR DAY (P4.1): the open
  /// goes through `resolveDayPlan` — the explicit pin or the rule-
  /// resolved placeholder — READ-ONLY (init never materializes; the day's
  /// own copy appears on the first write, see [_ensureDayMaterialized]).
  /// A day nothing claims falls back exactly like an unknown [timerId].
  /// When both are passed, [dayDate] wins (a day board's binding IS its
  /// plan).
  Future<void> init({String? timerId, DateTime? dayDate}) async {
    this.dayDate = dayDate;
    _dayMaterialized = false;
    final boards = await store.allBoards();
    // Chosen into a local first: the `board` field initializes exactly
    // once (a late field must not be written twice).
    var chosen = boards.isEmpty
        ? await store.createBoard('My Board')
        : boards.first;

    // What binds the controller: the day's resolved plan (P4.1) when a
    // date is given, else the requested timer id.
    final binding = this.dayDate != null
        ? await store.resolveDayPlan(this.dayDate!)
        : timerId;

    IntervalTimer? bound;
    if (binding != null) {
      final found = await _findTimer(binding, boards);
      if (found != null) {
        chosen = found.board;
        bound = found.timer;
      }
    }
    board = chosen;

    if (bound != null) {
      timer = bound;
    } else {
      final timers = await store.timersInBoard(board.id);
      timer = timers.isEmpty
          ? await store.createTimer(
              boardId: board.id,
              name: 'Interval timer',
              color: '#0055ff',
            )
          : timers.first;
    }

    await _buildSession();

    // Store failures inside flush() re-queue their entries (engine hardening)
    // and must not surface as unhandled async errors every second.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => tick().catchError((Object e) {
        debugPrint('planner: tick failed (run-log entries re-queued): $e');
      }),
    );
  }

  /// Re-reads the timer's definitions from the store and rebuilds the
  /// session (steps 3–5 of [init]) — keeps defs fresh after edits; the run
  /// state resets to [SessionState.notStarted]. The timer ENTITY is
  /// re-fetched too: the editor's commit updates name and color in the
  /// store, and the board reads both straight off [timer] — without this
  /// the readout color would stay stale until an app restart.
  Future<void> reload() async {
    final timers = await store.timersInBoard(board.id);
    timer = timers.firstWhere((t) => t.id == timer.id, orElse: () => timer);
    await _buildSession();
    notifyListeners();
  }

  /// Tweaks #8: the editor's Done — apply the edited tree WITHOUT
  /// resetting a live run. The session adopts the new schedule (the
  /// TWEAKS.md matrix: the current instance survives by identity, its
  /// remaining re-derives as new − elapsed, a deleted current continues
  /// at the next survivor, adjustments re-key). Idle behaves like a
  /// plain reload.
  ///
  /// P4.1: the tree-save path — a date-bound controller materializes the
  /// day's copy FIRST (the editor's own commit already landed there via
  /// [timerForWrite]; for direct callers this is where the fork happens).
  Future<void> applyTreeEdit() async {
    await _ensureDayMaterialized();
    final timers = await store.timersInBoard(board.id);
    timer = timers.firstWhere((t) => t.id == timer.id, orElse: () => timer);
    // Pending run-log entries belong to the old schedule — land them
    // before the processor is rebuilt over the edited one.
    await processor.flush();
    final tree = await store.loadTree(timer.id);
    this.tree = tree; // keep the board's row source current (P2.1)
    final next = flatten(tree);
    alerts = AlertHandler(
      player: player,
      notifier: notifier,
      soundsDir: soundsDir,
    );
    processor = RunEventProcessor(
      instances: next,
      store: store,
      timerName: timer.name,
      soundDirectoryListing: soundListing,
      alertSink: alerts,
    );
    session.adopt(next, sink: processor);
    instances = next;
    notifyListeners();
  }

  Future<void> _buildSession() async {
    final tree = await store.loadTree(timer.id);
    this.tree = tree; // the board's list view reads the tree (P2.1)
    instances = flatten(tree);
    alerts = AlertHandler(
      player: player,
      notifier: notifier,
      soundsDir: soundsDir,
    );
    processor = RunEventProcessor(
      instances: instances,
      store: store,
      timerName: timer.name,
      soundDirectoryListing: soundListing,
      alertSink: alerts,
    );
    session = TimerSession(instances, clock: clock, sink: processor);
  }

  /// Finds [timerId]'s plan across [boards] (the board that holds it,
  /// or null) — the [init] binding loop and the day-fork rebind in
  /// [_ensureDayMaterialized] share it.
  Future<({Board board, IntervalTimer timer})?> _findTimer(
    String timerId,
    List<Board> boards,
  ) async {
    for (final b in boards) {
      final match =
          (await store.timersInBoard(b.id)).where((t) => t.id == timerId);
      if (match.isNotEmpty) return (board: b, timer: match.first);
    }
    return null;
  }

  /// P4.1's lazy fork, idempotent — the hook EVERY date-bound write path
  /// awaits before touching anything:
  ///
  /// 1. not date-bound, or the day's copy already exists → no-op.
  /// 2. ask the store to `materializeDay` (read-only rule resolution + a
  ///    fresh copy of the plan AS IT STANDS, completion marks cleared —
  ///    an already-materialized day returns its own timer untouched).
  /// 3. rebind [timer]/[tree]/[session] to the day's own copy so the
  ///    pending write lands THERE, never on the placeholder.
  ///
  /// The rebind rebuilds the session — safe because this IS the day's
  /// FIRST write: no run can be live yet ([start] materializes before
  /// anything can run), and the copy is structurally identical to the
  /// placeholder it replaces. When nothing claims the day there is
  /// nothing to fork: the write proceeds on the bound timer unchanged.
  Future<void> _ensureDayMaterialized() async {
    final date = dayDate;
    if (date == null || _dayMaterialized) return;
    final forkedId = await store.materializeDay(date);
    if (forkedId == null) return; // no plan claims this day (yet)
    _dayMaterialized = true;
    if (forkedId == timer.id) return; // bound to the day's copy already
    final found = await _findTimer(forkedId, await store.allBoards());
    if (found == null) {
      throw StateError('materialized day timer not found: $forkedId');
    }
    timer = found.timer;
    await _buildSession(); // the copy's tree + a fresh not-started run
  }

  /// The timer a DEFINITION write must land on (P4.1's write seam for
  /// paths that resolve their own target — the editor's commit): awaits
  /// [_ensureDayMaterialized], then hands back the (possibly rebound)
  /// [timer].
  Future<IntervalTimer> timerForWrite() async {
    await _ensureDayMaterialized();
    return timer;
  }

  /// Heartbeat: settles the session at `clock.now()`, persists any queued
  /// terminal run-log entries, and notifies listeners. Public so tests can
  /// drive it directly on a fixed clock.
  Future<void> tick() async {
    session.settle(clock.now());
    await processor.flush();
    notifyListeners();
  }

  /// P4.1: a run start is a day's FIRST write — materialize + rebind
  /// before the session starts, so the run (and every mark it produces)
  /// lives on the day's own copy.
  Future<bool> start() async {
    await _ensureDayMaterialized();
    final started = session.start();
    notifyListeners();
    return started;
  }

  bool pause() {
    final paused = session.pause();
    notifyListeners();
    return paused;
  }

  bool resume() {
    final resumed = session.resume();
    notifyListeners();
    return resumed;
  }

  bool skipNext() {
    final skipped = session.skipNext();
    // Advancing completes a held-at-zero interval — its looping alert is
    // cut immediately (sound policy in AlertHandler), and any visible
    // notification goes with it (tweaks #9: no stale Continue).
    if (skipped) {
      alerts.stopAlerts();
      unawaited(notifier.closeVisible());
    }
    notifyListeners();
    return skipped;
  }

  bool jumpTo(int ordinal) {
    final jumped = session.jumpTo(ordinal);
    if (jumped) {
      alerts.stopAlerts();
      unawaited(notifier.closeVisible());
    }
    notifyListeners();
    return jumped;
  }

  /// Tweaks #7: ephemeral +/- seconds on the CURRENT instance's length
  /// for this run (never touches the saved definition). Clamping at zero
  /// ends the instance — manual → limbo, auto → next — through the normal
  /// event path (end alert + notification fire). Adding time to a held
  /// instance pulls it back to running. Returns whether it applied.
  /// P4.1: an adjustment is a day's first write — materialize first.
  Future<bool> adjustTime(int deltaSeconds) async {
    await _ensureDayMaterialized();
    final before = snapshot;
    final applied = session.adjustCurrent(deltaSeconds);
    if (applied) {
      final after = snapshot;
      final leftHold =
          before.state == SessionState.awaitingAdvance &&
          after.state != SessionState.awaitingAdvance;
      final moved = after.ordinal != before.ordinal;
      if (leftHold || moved) {
        // The run moved on: cut any loop and drop stale notifications
        // (the skipNext rule).
        alerts.stopAlerts();
        unawaited(notifier.closeVisible());
      }
    }
    notifyListeners();
    return applied;
  }

  /// Tweaks #5: silences the looping limbo alert WITHOUT advancing — the
  /// held instance keeps waiting (its notification stays clickable).
  void silenceAlarm() {
    alerts.stopAlerts();
    notifyListeners();
  }

  /// Toggles the completion mark of the item behind [ordinal] — the board
  /// list view's completion checkbox (P2.1; the engine owns the rules:
  /// marking the CURRENT item finishes it and advances). When the run
  /// moves, the same alert/notification cleanup as [skipNext] applies.
  /// Returns the new mark, or null when the ordinal is out of range.
  /// P4.1: a checkmark is a day's first write — materialize + rebind
  /// BEFORE the session op, so the mark and its persistence both land on
  /// the day's copy.
  Future<bool?> toggleMark(int ordinal) async {
    await _ensureDayMaterialized();
    final before = snapshot;
    final defId = instances[ordinal].defId;
    final marked = session.toggleMark(ordinal);
    if (marked == null) return null;
    _persistMark(defId, marked);
    final after = snapshot;
    if (after.ordinal != before.ordinal || after.state != before.state) {
      alerts.stopAlerts();
      unawaited(notifier.closeVisible());
    }
    notifyListeners();
    return marked;
  }

  /// v2 P2.2 — resolves a hold: [completed] is the Enter path (✓), false
  /// is the "not completed" button. Outside a hold it is a no-op.
  /// P4.1: same write-first rule as [toggleMark].
  Future<void> resolveHold({required bool completed}) async {
    await _ensureDayMaterialized();
    final before = snapshot;
    if (before.state != SessionState.awaitingAdvance) return;
    final defId = instances[before.ordinal!].defId;
    if (!session.resolveHold(completed: completed)) return;
    _persistMark(defId, completed);
    final after = snapshot;
    if (after.ordinal != before.ordinal || after.state != before.state) {
      alerts.stopAlerts();
      unawaited(notifier.closeVisible());
    }
    notifyListeners();
  }

  /// The def is the durable record (P1.1): the mark lands on the tree and
  /// is written through the normal save path — `run.mark` is both the
  /// change-log entry and the persistence write, fire-and-forget like the
  /// other UI-side store calls.
  void _persistMark(String defId, bool completed) {
    tree = tree.updated(defId, (d) => d.copyWith(completed: completed));
    unawaited(
      store
          .saveTree(
            timer.id,
            tree,
            eventKind: 'run.mark',
            eventPayload: {'defId': defId, 'completed': completed},
          )
          .catchError((Object e) {
            debugPrint('run.mark save failed: $e');
          }),
    );
  }

  Future<void> reset() async {
    // P4.1: the mark clearing is a day's write — materialize + rebind
    // BEFORE anything else, so the clearing runs against the day's copy
    // (never the placeholder, never a tree the rebind would discard).
    await _ensureDayMaterialized();
    session.reset();
    // v2 P1.3/P2.2: Reset un-completes every item — persisted too (the
    /// task-list "uncheck everything for the next trip" use case).
    var cleared = false;
    for (final id in tree.allIds.toSet()) {
      final node = tree.nodeById(id);
      if (node is DefNode && node.def.completed) {
        tree = tree.updated(id, (d) => d.copyWith(completed: false));
        cleared = true;
      }
    }
    if (cleared) {
      unawaited(
        store
            .saveTree(
              timer.id,
              tree,
              eventKind: 'run.mark',
              eventPayload: {'cleared': true},
            )
            .catchError((Object e) {
              debugPrint('run.mark save failed: $e');
            }),
      );
    }
    alerts.stopAlerts(); // abandoning the run cuts any alert sound
    unawaited(notifier.closeVisible());
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

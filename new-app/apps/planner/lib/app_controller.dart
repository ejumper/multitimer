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
  Future<void> init() async {
    final boards = await store.allBoards();
    board = boards.isEmpty
        ? await store.createBoard('My Board')
        : boards.first;

    final timers = await store.timersInBoard(board.id);
    timer = timers.isEmpty
        ? await store.createTimer(
            boardId: board.id,
            name: 'Interval timer',
            color: '#0055ff',
          )
        : timers.first;

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
  /// the dial color would stay stale until an app restart.
  Future<void> reload() async {
    final timers = await store.timersInBoard(board.id);
    timer = timers.firstWhere((t) => t.id == timer.id, orElse: () => timer);
    await _buildSession();
    notifyListeners();
  }

  Future<void> _buildSession() async {
    final tree = await store.loadTree(timer.id);
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

  /// Heartbeat: settles the session at `clock.now()`, persists any queued
  /// terminal run-log entries, and notifies listeners. Public so tests can
  /// drive it directly on a fixed clock.
  Future<void> tick() async {
    session.settle(clock.now());
    await processor.flush();
    notifyListeners();
  }

  bool start() {
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

  void reset() {
    session.reset();
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

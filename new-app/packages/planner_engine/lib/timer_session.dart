/// Execution state machine over a flattened schedule: start / pause /
/// resume / skip / jump / reset, with all timing derived from wall-clock
/// anchors via an injected [Clock] — never tick counting (CONVENTIONS §2).
///
/// The internal cursor is PROJECTED forward from its anchors on every read
/// ([snapshot]) and every explicit [settle]. [snapshot] is pure: it computes
/// the projection at the given instant without mutating anything and without
/// emitting events. [settle] applies the projection to the cursor and emits
/// the [InstanceEnded] events its zero-crossings produced, exactly once per
/// end. All mutating methods settle first (at `clock.now()`) before acting.
///
/// Derivation rule: elapsed = accumulated + (now − anchorStart), clamped at
/// zero for backwards clocks. A projected `running`/`paused` snapshot always
/// has remaining > Duration.zero — the crossing wins at exactly zero.
library;

import 'clock.dart';
import 'events.dart';
import 'flatten.dart';

/// Player lifecycle. No terminal `finished` state exists: reaching the end
/// of the list resets immediately to fresh [SessionState.notStarted].
enum SessionState {
  /// Fresh: nothing played; the snapshot shows the total planned time.
  notStarted,

  /// The current instance is consuming time.
  running,

  /// User-paused: the current instance's remaining is frozen.
  paused,

  /// A manually-complete ([IntervalInstance.autoFinish] == false) instance
  /// reached zero and holds AT ZERO until the user advances. Overshoot is
  /// absorbed here — the chain never cascades past a manual instance.
  awaitingAdvance,

  /// v2 P1.4: the run's plan is complete but a wall (dated interval) is
  /// still pending — the run waits, counting down to its trigger. The wall
  /// fires on its own; after it, the run is finished. (The North Star's
  /// "chain finished early before a wall → paused, counting down to it".)
  awaitingWall,
}

/// Immutable projection of the session cursor at one instant.
class TimerSnapshot {
  const TimerSnapshot({
    required this.state,
    required this.ordinal,
    required this.currentLabel,
    required this.remaining,
    required this.totalRemaining,
    required this.totalPlanned,
    this.late = false,
    this.suspendedOrdinal,
    this.suspendedRemaining,
  });

  /// Lifecycle state at the projected instant.
  final SessionState state;

  /// Current instance ordinal; null iff [SessionState.notStarted].
  final int? ordinal;

  /// The current instance's `name` snapshot (may be null); null iff
  /// [SessionState.notStarted].
  final String? currentLabel;

  /// The current instance's remaining; null iff [SessionState.notStarted],
  /// [Duration.zero] at [SessionState.awaitingAdvance].
  final Duration? remaining;

  /// Remaining of the current instance plus every future instance in this
  /// run; at [SessionState.notStarted] equals [totalPlanned].
  final Duration totalRemaining;

  /// Sum of all instances' planned durations — always shown, even fresh.
  final Duration totalPlanned;

  /// v2 P1.4: the current wall fired after its trigger (late flag for the
  /// UI badge — "you're late to this").
  final bool late;

  /// v2 P1.4: the occurrence a wall interrupted (suspended, not ended —
  /// it resumes when the wall completes); null when nothing is suspended.
  final int? suspendedOrdinal;

  /// The suspended occurrence's frozen remaining; null with [suspendedOrdinal].
  final Duration? suspendedRemaining;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerSnapshot &&
          other.state == state &&
          other.ordinal == ordinal &&
          other.currentLabel == currentLabel &&
          other.remaining == remaining &&
          other.totalRemaining == totalRemaining &&
          other.totalPlanned == totalPlanned &&
          other.late == late &&
          other.suspendedOrdinal == suspendedOrdinal &&
          other.suspendedRemaining == suspendedRemaining;

  @override
  int get hashCode => Object.hash(
    state,
    ordinal,
    currentLabel,
    remaining,
    totalRemaining,
    totalPlanned,
    late,
    suspendedOrdinal,
    suspendedRemaining,
  );

  @override
  String toString() =>
      'TimerSnapshot($state, ordinal=${ordinal ?? '-'}, '
      '${currentLabel ?? '<unnamed>'}, remaining=$remaining, '
      'totalRemaining=$totalRemaining, totalPlanned=$totalPlanned, '
      'late=$late, suspended=$suspendedOrdinal/$suspendedRemaining)';
}

/// The timer execution engine: plays a flattened schedule as a run with
/// wall-clock anchors, emitting one [InstanceEnded] per instance end
/// (zero-crossing → `done`; force-end before zero → `skipped`).
class TimerSession {
  TimerSession(
    List<IntervalInstance> instances, {
    required this.clock,
    required EventSink<InstanceEnded> sink,
    DateTime? wallDay,
  })  :
        // ignore: prefer_initializing_formals
        _wallDay = wallDay,
        _instances = instances,
       // ignore: prefer_initializing_formals
       _sink = sink {
    // v2 P1.3: seed the live marks from the items (the def is the durable
    // record — its `completed` means the whole item is checked, which
    // snapshots as completed for every occurrence).
    for (final i in instances) {
      if (i.completed) _completedOrdinals.add(i.ordinal);
    }
  }

  List<IntervalInstance> _instances;
  EventSink<InstanceEnded> _sink;

  // ── v2 P1.4: walls (dated intervals, interrupt & resume) ──────────

  /// The LOCAL calendar day the walls belong to (its date fields define
  /// the day start). Null = the run's start day (resolved at [start]).
  /// Passed explicitly by day boards (P4); frame-preserving math keeps
  /// the engine timezone-free.
  final DateTime? _wallDay;
  DateTime? _runWallDay;

  /// Walls that have fired OR otherwise played/ended this run — never
  /// re-fired. Cleared by [reset]/fresh [start].
  final Set<int> _firedWalls = {};

  /// Walls that fired after their trigger (the late badge).
  final Set<int> _lateWalls = {};

  /// The wall-detour suspension (the item the active wall interrupted);
  /// non-null iff [_activeWall] is. NOT logged at suspension — the item
  /// is paused-in-time, not ended.
  _Suspend? _suspended;
  int? _activeWall;

  bool _isWall(int i) => instances[i].triggerTimeSeconds != null;

  /// The wall's absolute fire instant (day start + time-of-day), or null
  /// for order-triggered instances.
  int? _wallMs(int i) {
    final t = instances[i].triggerTimeSeconds;
    if (t == null) return null;
    final d = _wallDay ?? _runWallDay;
    if (d == null) return null;
    final dayStart = d.isUtc
        ? DateTime.utc(d.year, d.month, d.day)
        : DateTime(d.year, d.month, d.day);
    return dayStart.millisecondsSinceEpoch + t * 1000;
  }

  /// The next non-wall ordinal at or after [from] (the chain's flow never
  /// LANDS on walls — they run only as time-fired detours; jumping may).
  int? _nextRunnable(int from) {
    for (var j = from; j < instances.length; j++) {
      if (!_isWall(j)) return j;
    }
    return null;
  }

  /// The earliest wall that is pending (not fired, not completed).
  int? _earliestPending(Set<int> fired, Set<int> marked) {
    var best = -1;
    var bestMs = 0;
    for (var j = 0; j < instances.length; j++) {
      final wms = _wallMs(j);
      if (wms == null || fired.contains(j) || marked.contains(j)) continue;
      if (best == -1 || wms < bestMs) {
        best = j;
        bestMs = wms;
      }
    }
    return best == -1 ? null : best;
  }

  /// The flattened schedule to play; [IntervalInstance.ordinal] == index.
  List<IntervalInstance> get instances => _instances;

  /// Injected time source; the session never reads the OS clock.
  final Clock clock;

  /// Injected sink for [InstanceEnded] events.
  EventSink<InstanceEnded> get sink => _sink;

  static const _Cursor _fresh = _Cursor(SessionState.notStarted, null, 0, 0);

  _Cursor _cursor = _fresh;

  /// Per-run ephemeral duration adjustments (tweaks #7): ordinal → added
  /// milliseconds. NOT part of the saved definition — they live on this
  /// session only, and an instance plays at its ADJUSTED length however
  /// the run reaches it (including jumpTo's fresh restart).
  final Map<int, int> _adjustMs = <int, int>{};

  /// The instance's length for THIS run: planned + the ephemeral adjust.
  int _effectiveMs(int ordinal) =>
      (instances[ordinal].durationSeconds ?? 0) * 1000 + (_adjustMs[ordinal] ?? 0);

  /// Starts the run on instance 0 (accumulated=0, anchor=now). Returns true
  /// only from [SessionState.notStarted] with a non-empty schedule; an empty
  /// schedule stays notStarted and returns false.
  bool start() {
    final nowMs = _settleAtClock();
    if (_cursor.state != SessionState.notStarted || instances.isEmpty) {
      return false;
    }
    _adjustMs.clear(); // a fresh run replays the plan (tweaks #7 bugfix)
    // v2 P1.4: walls belong to the run's day unless pinned (day boards);
    // a fresh run re-fires nothing that already played (the fired set is
    // per-run).
    _runWallDay ??= clock.now();
    _firedWalls.clear();
    _lateWalls.clear();
    _suspended = null;
    _activeWall = null;
    // The chain's flow starts at the first RUNNABLE instance (walls at
    // the top don't stall the day — they fire at their times as detours).
    final first = _nextRunnable(0);
    if (first == null) {
      final w = _earliestPending(_firedWalls, _completedOrdinals);
      if (w == null) return false;
      _cursor = _Cursor(SessionState.awaitingWall, w, 0, nowMs);
    } else {
      _cursor = _Cursor(SessionState.running, first, 0, nowMs);
    }
    return true;
  }

  /// Freezes the running instance's remaining. Returns true only from
  /// [SessionState.running]; a zero-crossing settled first wins (e.g. a
  /// manually-complete instance paused AT zero returns false and sits
  /// awaitingAdvance).
  bool pause() {
    final nowMs = _settleAtClock();
    if (_cursor.state != SessionState.running) return false;
    final sinceAnchor = nowMs - _cursor.anchorMs;
    final frozenElapsed =
        _cursor.accumulatedMs + (sinceAnchor > 0 ? sinceAnchor : 0);
    _cursor = _Cursor(
      SessionState.paused,
      _cursor.ordinal,
      frozenElapsed,
      nowMs,
    );
    return true;
  }

  /// Resumes a paused instance by re-anchoring (accumulated = frozen elapsed,
  /// anchor = now). Returns true only from [SessionState.paused].
  bool resume() {
    final nowMs = _settleAtClock();
    if (_cursor.state != SessionState.paused) return false;
    _cursor = _Cursor(
      SessionState.running,
      _cursor.ordinal,
      _cursor.accumulatedMs,
      nowMs,
    );
    return true;
  }

  /// Tweaks #8 — live tree edit (the TWEAKS.md matrix, spec-aligned:
  /// native MultiTimer applies config edits from ANY state). Swaps in the
  /// edited schedule mid-run and maps the run state onto it BY IDENTITY
  /// (defId + occurrence — flattened repeats share defIds). Returns
  /// whether a live run continues on the new schedule.
  ///
  /// Rules:
  ///  - the current instance survives (rename/reorder/reparent anywhere):
  ///    stay on it; elapsed is kept and remaining re-derives as
  ///    newLength − elapsed (the duration-delta rule, clamped at zero →
  ///    the [adjustCurrent] clamp semantics: `done` once, manual → hold,
  ///    auto → next full — a held instance never logs `done` twice);
  ///  - a held instance that GAINED length is promoted back to running
  ///    (the add-time rule) with exactly the gained amount;
  ///  - the current instance is deleted: the run continues at the first
  ///    survivor that came after it (first in the NEW order) with full
  ///    remaining (paused runs park paused-ready); nothing after it
  ///    survives → the run completes cleanly. NO run-log event either
  ///    way — the edit belongs to the tree's change log, not run time;
  ///  - repeat counts shrinking clamp the occurrence to the nearest
  ///    surviving one; per-run adjustments re-key by the same identity;
  ///  - empty schedule → clean end.
  bool adopt(
    List<IntervalInstance> next, {
    EventSink<InstanceEnded>? sink,
  }) {
    final nowMs = _settleAtClock(); // old-schedule events land first
    final prev = _instances;
    if (sink != null) _sink = sink;

    // Identity keys: (defId, occurrence index) over the old schedule.
    final keyOf = <int, (String, int)>{};
    final seenOld = <String, int>{};
    for (var i = 0; i < prev.length; i++) {
      final d = prev[i].defId;
      final occ = seenOld[d] ?? 0;
      seenOld[d] = occ + 1;
      keyOf[i] = (d, occ);
    }
    // The new schedule's identities; occurrence clamps to the LAST
    // surviving one when repeats shrank.
    final occOf = <(String, int), int>{};
    final lastOf = <String, int>{};
    final seenNew = <String, int>{};
    for (var j = 0; j < next.length; j++) {
      final d = next[j].defId;
      final occ = seenNew[d] ?? 0;
      seenNew[d] = occ + 1;
      occOf[(d, occ)] = j;
      lastOf[d] = j;
    }

    int? map(int oldOrdinal) {
      final key = keyOf[oldOrdinal]!;
      return occOf[key] ?? lastOf[key.$1];
    }

    // Per-run adjustments follow their instances (tweaks #7 layer).
    final oldAdjust = Map<int, int>.of(_adjustMs);
    final newAdjust = <int, int>{};
    for (final e in oldAdjust.entries) {
      final j = map(e.key);
      if (j != null) newAdjust[j] = (newAdjust[j] ?? 0) + e.value;
    }
    // v2 P1.3/1.4: the marks and wall state are ordinal-keyed too — they
    // re-key by the same identity (dropped when their item is gone).
    Set<int> rekey(Set<int> ordinals) => {
      for (final o in ordinals)
        if (map(o) != null) map(o)!,
    };
    final newMarked = rekey(_completedOrdinals);
    final newFired = rekey(_firedWalls);
    final newLate = rekey(_lateWalls);
    final oldSuspended = _suspended;
    final newSuspended = (oldSuspended == null || oldSuspended.finished)
        ? oldSuspended
        : (map(oldSuspended.ordinal!) == null
              ? const _Suspend.finished()
              : _Suspend.item(
                  map(oldSuspended.ordinal!)!,
                  oldSuspended.remainingMs,
                  oldSuspended.state,
                ));
    final newActiveWall = _activeWall == null ? null : map(_activeWall!);

    final state = _cursor.state;
    _instances = next;
    _adjustMs
      ..clear()
      ..addAll(newAdjust);
    _completedOrdinals
      ..clear()
      ..addAll(newMarked);
    _firedWalls
      ..clear()
      ..addAll(newFired);
    _lateWalls
      ..clear()
      ..addAll(newLate);
    _suspended = newSuspended;
    _activeWall = newActiveWall;

    if (state == SessionState.notStarted || next.isEmpty) {
      _cursor = _fresh;
      return false;
    }

    final oldOrdinal = _cursor.ordinal!;
    final j = map(oldOrdinal);
    if (j == null) {
      // The current instance is gone: the show goes on at the first
      // survivor that came AFTER it (first in the new order).
      final candidates = <int>[];
      for (var i = oldOrdinal + 1; i < prev.length; i++) {
        final m = map(i);
        if (m != null) candidates.add(m);
      }
      candidates.sort();
      if (candidates.isEmpty) {
        _cursor = _fresh;
        return false;
      }
      // The hold belonged to the deleted instance — a live run takes the
      // successor over with full remaining (the jumpTo parking rule).
      _cursor = _Cursor(
        state == SessionState.paused ? SessionState.paused : SessionState.running,
        candidates.first,
        0,
        nowMs,
      );
      return true;
    }

    // The current survives: keep its elapsed, re-derive the remaining
    // against the edited length (the user's delta rule: 5min into a 10min
    // interval edited to 15min → 10min left = 15 − 5).
    final oldEffectiveMs =
        (prev[oldOrdinal].durationSeconds ?? 0) * 1000 + (oldAdjust[oldOrdinal] ?? 0);
    final int elapsedMs;
    if (state == SessionState.awaitingAdvance) {
      elapsedMs = oldEffectiveMs; // a held instance consumed its length
    } else {
      final sinceAnchor =
          state == SessionState.running && nowMs > _cursor.anchorMs
          ? nowMs - _cursor.anchorMs
          : 0;
      elapsedMs = _cursor.accumulatedMs + sinceAnchor;
    }
    final newEffectiveMs =
        (next[j].durationSeconds ?? 0) * 1000 + (_adjustMs[j] ?? 0);
    final remainingMs = newEffectiveMs - elapsedMs;

    if (remainingMs <= 0) {
      // Clamp at zero — but a HELD instance already logged its `done`.
      if (!_isManual(j)) _completedOrdinals.add(j); // auto-completes its pass
      if (state != SessionState.awaitingAdvance) {
        _sink.emit(
          InstanceEnded(
            ordinal: j,
            defId: next[j].defId,
            terminal: TerminalState.done,
            endedAt: DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
            completed: _completedOrdinals.contains(j),
          ),
        );
      }
      _adjustMs.remove(j);
      if (_isManual(j)) {
        _cursor = _Cursor(SessionState.awaitingAdvance, j, 0, nowMs);
      } else if (j == next.length - 1) {
        _cursor = _fresh;
      } else {
        _cursor = _Cursor(
          state == SessionState.paused ? SessionState.paused : SessionState.running,
          j + 1,
          0,
          nowMs,
        );
      }
      return true;
    }
    // Continue on the same instance; a held instance that gained length
    // is promoted back to running (the add-time rule).
    _cursor = _Cursor(
      state == SessionState.awaitingAdvance ? SessionState.running : state,
      j,
      elapsedMs,
      nowMs,
    );
    return true;
  }

  /// Tweaks #7 — ephemeral time adjustment of the CURRENT instance's
  /// remaining (never touches the saved definition; lives on this run's
  /// cursor only). [deltaSeconds] is signed; legal while running, paused,
  /// or awaitingAdvance (else false). A zero delta is a no-op (false).
  ///
  /// Clamp rule (TWEAKS.md): an adjustment that would take the remaining
  /// below zero clamps AT zero — the instance ends exactly now with
  /// `done` (not `skipped`): a manually-complete instance lands in
  /// [SessionState.awaitingAdvance] (limbo — alarm + notification fire
  /// through the normal event path), an auto-finish one flows into the
  /// next instance with FULL remaining (the excess is discarded, never
  /// cascaded), and a paused run stays paused (the next instance parks
  /// full remaining — the [jumpTo] rule).
  ///
  /// Adding time to a held (awaitingAdvance) instance pulls it out of
  /// limbo back to running with EXACTLY that much remaining (the instance
  /// already consumed its planned duration — the delta is all it gets).
  bool adjustCurrent(int deltaSeconds) {
    final nowMs = _settleAtClock();
    final state = _cursor.state;
    if (state == SessionState.notStarted) return false;
    final i = _cursor.ordinal!;
    final deltaMs = deltaSeconds * 1000;
    if (deltaMs == 0) return false;

    if (state == SessionState.awaitingAdvance) {
      if (deltaMs < 0) return false; // already at zero — nothing to remove
      _adjustMs[i] = (_adjustMs[i] ?? 0) + deltaMs;
      _cursor = _Cursor(
        SessionState.running,
        i,
        _effectiveMs(i) - deltaMs,
        nowMs,
      );
      return true;
    }

    // running / paused remaining at this instant (a paused cursor is
    // frozen at its accumulated elapsed).
    final sinceAnchor =
        state == SessionState.running && nowMs > _cursor.anchorMs
        ? nowMs - _cursor.anchorMs
        : 0;
    final remainingMs = _effectiveMs(i) - _cursor.accumulatedMs - sinceAnchor;
    if (remainingMs + deltaMs <= 0) {
      // Clamp at zero: the instance ends exactly now as `done` and the
      // normal zero-crossing rules decide what follows.
      if (!_isManual(i)) _completedOrdinals.add(i); // auto-completes its pass
      sink.emit(
        InstanceEnded(
          ordinal: i,
          defId: instances[i].defId,
          terminal: TerminalState.done,
          endedAt: DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
          completed: _completedOrdinals.contains(i),
        ),
      );
      _adjustMs.remove(i); // absorbed by the completion
      if (_isManual(i)) {
        _cursor = _Cursor(SessionState.awaitingAdvance, i, 0, nowMs);
      } else {
        _advanceFrom(
          i,
          nowMs,
          pausedCarry: state == SessionState.paused,
        ); // v2 P1.4: wall-aware (detour return / pending wait)
      }
      return true;
    }
    // Plain adjustment: the instance's length for this run changes — the
    // cursor (anchor, paused/running semantics) is untouched.
    _adjustMs[i] = (_adjustMs[i] ?? 0) + deltaMs;
    return true;
  }

  /// Forces the current instance to end and advances. Legal from running,
  /// paused, and awaitingAdvance (else false). A current instance that had
  /// NOT reached zero emits [TerminalState.skipped]; an awaitingAdvance
  /// current already emitted `done` at its zero-crossing — no duplicate.
  /// Advances to the next instance (running, full remaining, anchor=now) or,
  /// if none is left, resets to fresh [SessionState.notStarted].
  bool skipNext() {
    final nowMs = _settleAtClock();
    final state = _cursor.state;
    if (state == SessionState.notStarted) return false;
    if (state != SessionState.awaitingAdvance) {
      _emitSkipped(_cursor.ordinal!, nowMs);
    }
    _advanceFrom(_cursor.ordinal!, nowMs);
    return true;
  }

  /// Repositions the run onto [ordinal]. Returns false if the ordinal is out
  /// of range (or the schedule is empty). A run in progress (running,
  /// paused, or awaitingAdvance) force-ends its current instance per the
  /// [skipNext] rule; a FORWARD jump mid-run also logs the strictly
  /// in-between instances as `skipped` (they never ran) — backward jumps
  /// and jumps from notStarted emit nothing for them. A running session
  /// keeps running at the target; a paused/awaitingAdvance/notStarted
  /// session parks the target `paused`-ready (full remaining).
  bool jumpTo(int ordinal) {
    final nowMs = _settleAtClock();
    if (instances.isEmpty || ordinal < 0 || ordinal >= instances.length) {
      return false;
    }
    final state = _cursor.state;
    if (state == SessionState.notStarted) {
      _adjustMs.clear(); // choose-interval on a fresh session = a new run
    }
    final midRun =
        state == SessionState.running ||
        state == SessionState.paused ||
        state == SessionState.awaitingAdvance ||
        state == SessionState.awaitingWall;
    if (midRun) {
      final current = _cursor.ordinal!;
      if (state != SessionState.awaitingAdvance) {
        _emitSkipped(current, nowMs);
      }
      if (ordinal > current) {
        for (var j = current + 1; j < ordinal; j++) {
          // v2 P1.4: walls are never "jumped over" — they stay pending
          // and fire at their times. Only real work is logged as skipped.
          if (!_isWall(j)) _emitSkipped(j, nowMs);
        }
      }
    }
    // v2 P1.4: navigation abandons a wall detour — the suspended item
    // was mid-flight and never logged, so it closes here (exactly-once).
    final save = _suspended;
    _suspended = null;
    _activeWall = null;
    if (save != null && !save.finished) _emitSkipped(save.ordinal!, nowMs);
    if (_isWall(ordinal)) _firedWalls.add(ordinal); // landed = played
    _cursor = _Cursor(
      state == SessionState.running || state == SessionState.awaitingWall
          ? SessionState.running
          : SessionState.paused,
      ordinal,
      0,
      nowMs,
    );
    return true;
  }

  /// Returns to fresh [SessionState.notStarted] from any state. A run in
  /// progress whose current instance had not zeroed emits
  /// [TerminalState.skipped] for it; a zeroed/awaitingAdvance current already
  /// logged `done`. From notStarted: no-op, no events.
  void reset() {
    _adjustMs.clear(); // the run is over — the next one is unadjusted
    _completedOrdinals.clear(); // v2 P1.3: reset un-completes every item
    final nowMs = _settleAtClock();
    // v2 P1.4: an abandoned detour logs its suspended item (exactly-once
    // holds — it never ended otherwise) and the wall state goes with it.
    final save = _suspended;
    _suspended = null;
    _activeWall = null;
    _firedWalls.clear();
    _lateWalls.clear();
    if (_cursor.state == SessionState.notStarted) {
      if (save != null && !save.finished) _emitSkipped(save.ordinal!, nowMs);
      return;
    }
    if (_cursor.state == SessionState.awaitingAdvance) {
      // its `done` already stands
    } else if (_cursor.state == SessionState.awaitingWall) {
      _emitSkipped(_cursor.ordinal!, nowMs); // the wait is abandoned
    } else {
      _emitSkipped(_cursor.ordinal!, nowMs);
    }
    if (save != null && !save.finished) _emitSkipped(save.ordinal!, nowMs);
    _cursor = _fresh;
  }

  /// Projects the cursor at [now] WITHOUT mutating anything and WITHOUT
  /// emitting events. Calling twice with the same [now] gives identical
  /// results and zero side effects.
  TimerSnapshot snapshot(DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    final projection = _project(_cursor, nowMs);
    return _toSnapshot(
      projection.cursor,
      nowMs,
      slot: projection.slot,
      late: projection.lateWalls.contains(projection.cursor.ordinal),
    );
  }

  /// Applies the projection at [now] to the internal cursor and emits every
  /// [InstanceEnded] produced by zero-crossings along the way (exactly once
  /// per end). The app calls this on its heartbeat.
  void settle(DateTime now) => _settleAt(now.millisecondsSinceEpoch);

  /// Settles at `clock.now()`; returns that instant in ms so callers act on
  /// the exact instant they settled at (uniform single clock read).
  int _settleAtClock() {
    final nowMs = clock.now().millisecondsSinceEpoch;
    _settleAt(nowMs);
    return nowMs;
  }

  void _settleAt(int nowMs) {
    final projection = _project(_cursor, nowMs);
    _cursor = projection.cursor;
    for (final event in projection.events) {
      sink.emit(event);
    }
    // P1.3/1.4: only a settle applies simulated state (purity rule).
    _completedOrdinals.addAll(projection.marked);
    _firedWalls.addAll(projection.fired);
    _lateWalls.addAll(projection.lateWalls);
    _suspended = projection.slot;
    _activeWall = projection.activeWall;
  }

  /// v2 P1.3 — the run's live completion marks, keyed by OCCURRENCE
  /// (ordinal). Per-occurrence is what the chain needs (a repeated item's
  /// passes complete one by one); the ITEM view — the row's checkbox — is
  /// derived: an item is completed when ALL its occurrences are marked.
  /// Cleared by [reset]; seeded from the instances; toggleable any time.
  final Set<int> _completedOrdinals = {};

  /// The items (def ids) whose every occurrence is marked — the checkbox
  /// state, and the durable record the app persists on the def.
  Set<String> get completedDefIds => {
    for (final entry in _groupByDef().entries)
      if (entry.value.every(_completedOrdinals.contains)) entry.key,
  };

  /// Whether the ITEM behind [defId] is fully marked (all occurrences).
  bool isCompleted(String defId) =>
      _groupByDef()[defId]?.every(_completedOrdinals.contains) ?? false;

  Map<String, List<int>> _groupByDef() {
    final byDef = <String, List<int>>{};
    for (final i in instances) {
      (byDef[i.defId] ??= []).add(i.ordinal);
    }
    return byDef;
  }

  /// Toggles the ITEM behind [ordinal]: marking marks every occurrence of
  /// its def (a checked item's remaining passes fly past when reached);
  /// unchecking un-marks them all. Toggling an item ON while it is the
  /// CURRENT one finishes it (the spec sentence: "if it's the current
  /// interval, it finishes it and marks it complete") — `done` ("user moved
  /// past it") and the chain advances past any already-completed items.
  /// The caller persists the new item state ([isCompleted]); the def is the
  /// durable record. Returns the new item mark, or null if out of range.
  bool? toggleMark(int ordinal) {
    final nowMs = _settleAtClock();
    if (ordinal < 0 || ordinal >= instances.length) return null;
    final defId = instances[ordinal].defId;
    final marking = !isCompleted(defId);
    for (final j in _groupByDef()[defId]!) {
      if (marking) {
        _completedOrdinals.add(j);
      } else {
        _completedOrdinals.remove(j);
      }
    }
    final atCurrent =
        marking &&
        _cursor.state != SessionState.notStarted &&
        _cursor.state != SessionState.awaitingWall &&
        instances[_cursor.ordinal!].defId == defId;
    if (atCurrent) {
      if (_cursor.state != SessionState.awaitingAdvance) {
        // Mid-flight: the user moved past it — `done`, logged once.
        sink.emit(
          InstanceEnded(
            ordinal: _cursor.ordinal!,
            defId: defId,
            terminal: TerminalState.done,
            endedAt: DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
            completed: true,
          ),
        );
      } // at a hold its `done` already stands — no duplicate.
      _advanceFrom(_cursor.ordinal!, nowMs);
      _settleAt(nowMs); // cascade past any completed items ahead
    }
    return marking;
  }

  /// Resolves a hold ([SessionState.awaitingAdvance]) for the CURRENT
  /// occurrence: [completed] is the Enter path (✓), `false` is the "not
  /// completed" button. Advances to the next occurrence. False when not at
  /// a hold. (For a repeated item the passes resolve one by one — the row's
  /// checkbox lights when the last pass is done.)
  bool resolveHold({required bool completed}) {
    final nowMs = _settleAtClock();
    if (_cursor.state != SessionState.awaitingAdvance) return false;
    final i = _cursor.ordinal!;
    if (completed) {
      _completedOrdinals.add(i);
    } else {
      _completedOrdinals.remove(i);
    }
    _advanceFrom(i, nowMs);
    _settleAt(nowMs);
    return true;
  }

  /// v2 P1.2 — the EFFECTIVE finish method. An Open instance (no duration)
  /// always completes manually: the authored autoFinish flag is ignored
  /// (authoring requires a duration for auto-finish; this is the engine's
  /// defense in depth). Everything else honors the authored method.
  bool _isManual(int i) =>
      instances[i].durationSeconds == null || !instances[i].autoFinish;

  void _emitSkipped(int ordinal, int atMs) {
    sink.emit(
      InstanceEnded(
        ordinal: ordinal,
        defId: instances[ordinal].defId,
        terminal: TerminalState.skipped,
        endedAt: DateTime.fromMillisecondsSinceEpoch(atMs, isUtc: true),
        completed: _completedOrdinals.contains(ordinal),
      ),
    );
  }

  /// The mutator-side end transition — mirrors the projection's: a wall
  /// detour RETURNS to its suspension, otherwise the chain continues at
  /// the next runnable instance (walls are never landed on), or waits
  /// ([SessionState.awaitingWall]) for a pending wall, or ends fresh.
  /// An ended wall is recorded as played (never re-fires).
  void _advanceFrom(int lastOrdinal, int nowMs, {bool pausedCarry = false}) {
    if (instances[lastOrdinal].isDated) _firedWalls.add(lastOrdinal);
    if (_activeWall == lastOrdinal) {
      final save = _suspended;
      _suspended = null;
      _activeWall = null;
      if (save == null || save.finished) {
        _cursor = _fresh;
      } else {
        _cursor = _Cursor(
          save.state,
          save.ordinal!,
          _effectiveMs(save.ordinal!) - save.remainingMs,
          nowMs,
        );
      }
      return;
    }
    final next = _nextRunnable(lastOrdinal + 1);
    if (next == null) {
      final w = _earliestPending(_firedWalls, _completedOrdinals);
      _cursor = w == null
          ? _fresh
          : _Cursor(SessionState.awaitingWall, w, 0, nowMs);
    } else {
      _cursor = _Cursor(
        pausedCarry ? SessionState.paused : SessionState.running,
        next,
        0,
        nowMs,
      );
    }
  }

  /// The projection algorithm. Derives the cursor forward from wall-clock
  /// anchors; cascades auto-finish crossings in one pass; collects the
  /// `done` events the crossings produced.
  /// The projection algorithm — a MERGED timeline simulation (v2 P1.4):
  /// wall firings and zero-crossings interleave in TRUE instant order,
  /// with the wall-detour returns folded in. PURE: it copies the mutable
  /// run state (cursor, suspension, fired/marked sets), simulates, and
  /// returns the result — only _settleAt applies it (snapshot must not
  /// mutate anything).
  _Projection _project(_Cursor cursor0, int nowMs) {
    var current = cursor0;
    var slot = _suspended;
    var activeWall = _activeWall;
    final fired = {..._firedWalls};
    final lateWalls = {..._lateWalls};
    final marked = {..._completedOrdinals};
    final events = <InstanceEnded>[];

    // The shared end transition: the wall-detour return, the next
    // runnable instance, or the pending-wall wait / fresh end.
    void endTransition(int i, int endMs) {
      if (instances[i].isDated) fired.add(i); // played — never re-fires
      if (activeWall == i) {
        // The detour completes: back to the suspended item (or a run
        // that was already complete).
        final save = slot;
        slot = null;
        activeWall = null;
        if (save == null || save.finished) {
          current = _fresh;
        } else {
          current = _Cursor(
            save.state,
            save.ordinal!,
            _effectiveMs(save.ordinal!) - save.remainingMs,
            endMs,
          );
        }
        return;
      }
      final next = _nextRunnable(i + 1);
      if (next == null) {
        final w = _earliestPending(fired, marked);
        current = w == null
            ? _fresh
            : _Cursor(SessionState.awaitingWall, w, 0, endMs);
      } else {
        current = _Cursor(SessionState.running, next, 0, endMs);
      }
    }

    while (true) {
      // A REACHED, pre-completed occurrence flies past instantly (P1.3):
      // it already happened — the chain never runs or holds on it. (Only
      // running cursors: a jump that lands paused on completed work sits
      // until resumed.)
      if (current.state == SessionState.running &&
          marked.contains(current.ordinal!)) {
        final reachedMs = current.anchorMs - current.accumulatedMs;
        events.add(
          InstanceEnded(
            ordinal: current.ordinal!,
            defId: instances[current.ordinal!].defId,
            terminal: TerminalState.skipped,
            endedAt: DateTime.fromMillisecondsSinceEpoch(
              reachedMs,
              isUtc: true,
            ),
            completed: true,
          ),
        );
        endTransition(current.ordinal!, reachedMs);
        continue;
      }
      // Normalize a wait whose wall is gone (checked while waiting — a
      // completed wall never runs; or already fired): move the wait to the
      // next pending wall, else the run is finished.
      if (current.state == SessionState.awaitingWall) {
        final w = current.ordinal!;
        if (fired.contains(w) || marked.contains(w) || _wallMs(w) == null) {
          final nextW = _earliestPending(fired, marked);
          current = nextW == null
              ? _fresh
              : _Cursor(SessionState.awaitingWall, nextW, 0, nowMs);
          continue;
        }
        // The wall is still pending: a due wall fires below; a future one
        // keeps counting down (nothing left to simulate this settle).
      }

      // (a) the earliest DUE wall. A running detour wall whose own start
      // is at/after a candidate's time holds it back (catch-up: the wall
      // fires when the running one ends); a candidate whose time arrived
      // LIVE during the running wall cuts it (later cuts earlier).
      final wallStart =
          (activeWall != null && activeWall == current.ordinal)
          ? current.anchorMs - current.accumulatedMs
          : null;
      var fireOrdinal = -1;
      var fireMs = 0;
      for (var j = 0; j < instances.length; j++) {
        final wms = _wallMs(j);
        if (wms == null || wms > nowMs) continue;
        if (fired.contains(j) || marked.contains(j)) continue;
        if (wallStart != null && wms <= wallStart) continue; // queued
        if (fireOrdinal == -1 || wms < fireMs) {
          fireOrdinal = j;
          fireMs = wms;
        }
      }

      // (b) the running cursor's next zero-crossing instant.
      var crossMs = 0;
      if (current.state == SessionState.running) {
        crossMs =
            current.anchorMs +
            (_effectiveMs(current.ordinal!) - current.accumulatedMs);
      }

      if (fireOrdinal != -1 &&
          current.state != SessionState.notStarted &&
          (crossMs == 0 || fireMs <= crossMs)) {
        // (walls fire only into a LIVE run — an idle timer is never
        // interrupted by the clock)
        // FIRE (interrupt & resume). The wall runs with full remaining
        // anchored at the settle now — a wall is never "partly played"
        // just because the system slept past its trigger.
        fired.add(fireOrdinal);
        if (nowMs - fireMs > 2000) lateWalls.add(fireOrdinal);
        final st = current.state;
        if (st == SessionState.awaitingWall) {
          // The plan was already complete — the wall is the finale.
          slot = const _Suspend.finished();
        } else if (st == SessionState.awaitingAdvance) {
          // A held item auto-resolves COMPLETED when a wall takes over
          // (its done already stands); the chain continues after it.
          marked.add(current.ordinal!);
          final nextOrd = _nextRunnable(current.ordinal! + 1);
          slot = nextOrd == null
              ? const _Suspend.finished()
              : _Suspend.item(nextOrd, _effectiveMs(nextOrd), SessionState.running);
        } else if (activeWall != null && activeWall == current.ordinal) {
          // Wall-vs-wall: the running wall is CUT (actual < planned,
          // not completed) — the ORIGINAL suspension beneath survives.
          events.add(
            InstanceEnded(
              ordinal: current.ordinal!,
              defId: instances[current.ordinal!].defId,
              terminal: TerminalState.cut,
              endedAt: DateTime.fromMillisecondsSinceEpoch(
                fireMs,
                isUtc: true,
              ),
              completed: marked.contains(current.ordinal!),
            ),
          );
        } else {
          // Mid-flight item: suspend (position + remaining + state). A
          // paused item is FROZEN — it consumes nothing while suspended.
          final elapsed = st == SessionState.paused
              ? current.accumulatedMs
              : current.accumulatedMs +
                    (fireMs > current.anchorMs
                        ? fireMs - current.anchorMs
                        : 0);
          slot = _Suspend.item(
            current.ordinal!,
            _effectiveMs(current.ordinal!) - elapsed,
            st,
          );
        }
        activeWall = fireOrdinal;
        current = _Cursor(SessionState.running, fireOrdinal, 0, nowMs);
        continue;
      }

      if (crossMs != 0 && crossMs <= nowMs) {
        final i = current.ordinal!;
        final endedAtMs = crossMs;
        final completes = !_isManual(i) || marked.contains(i);
        if (!_isManual(i)) marked.add(i);
        events.add(
          InstanceEnded(
            ordinal: i,
            defId: instances[i].defId,
            terminal: TerminalState.done,
            endedAt: DateTime.fromMillisecondsSinceEpoch(
              endedAtMs,
              isUtc: true,
            ),
            completed: completes,
          ),
        );
        if (_isManual(i)) {
          // Hold at exactly zero — the mark stays undecided until the
          // user resolves it.
          current = _Cursor(SessionState.awaitingAdvance, i, 0, endedAtMs);
          break;
        }
        endTransition(i, endedAtMs);
        continue;
      }
      break;
    }
    return _Projection(
      current,
      events,
      marked,
      fired,
      lateWalls,
      slot,
      activeWall,
    );
  }

  TimerSnapshot _toSnapshot(
    _Cursor cursor,
    int nowMs, {
    _Suspend? slot,
    bool late = false,
  }) {
    final planned = totalPlanned(instances);
    // The wall-detour view: what the interruption froze.
    final suspendedOrdinal = (slot != null && !slot.finished) ? slot.ordinal : null;
    final suspendedRemaining = suspendedOrdinal == null
        ? null
        : Duration(milliseconds: slot!.remainingMs);
    switch (cursor.state) {
      case SessionState.notStarted:
        return TimerSnapshot(
          state: SessionState.notStarted,
          ordinal: null,
          currentLabel: null,
          remaining: null,
          totalRemaining: planned,
          totalPlanned: planned,
        );
      case SessionState.awaitingAdvance:
        final i = cursor.ordinal!;
        return TimerSnapshot(
          state: SessionState.awaitingAdvance,
          ordinal: i,
          currentLabel: instances[i].name,
          remaining: Duration.zero, // holds at zero regardless of overshoot
          totalRemaining: _detourRemaining(_futureRemaining(i + 1), slot),
          totalPlanned: planned,
          late: late,
          suspendedOrdinal: suspendedOrdinal,
          suspendedRemaining: suspendedRemaining,
        );
      case SessionState.awaitingWall:
        final i = cursor.ordinal!;
        final waitMs = (_wallMs(i) ?? nowMs) - nowMs;
        return TimerSnapshot(
          state: SessionState.awaitingWall,
          ordinal: i,
          currentLabel: instances[i].name,
          // The countdown TO the wall is the meaningful clock here.
          remaining: Duration(milliseconds: waitMs > 0 ? waitMs : 0),
          totalRemaining: Duration(milliseconds: _effectiveMs(i)),
          totalPlanned: planned,
          late: late,
        );
      case SessionState.running:
      case SessionState.paused:
        final i = cursor.ordinal!;
        final durationMs = _effectiveMs(i);
        final sinceAnchor = nowMs - cursor.anchorMs;
        // Paused freezes at accumulated; only running consumes wall time.
        final elapsed = cursor.state == SessionState.running
            ? cursor.accumulatedMs + (sinceAnchor > 0 ? sinceAnchor : 0)
            : cursor.accumulatedMs;
        final remaining = Duration(milliseconds: durationMs - elapsed);
        return TimerSnapshot(
          state: cursor.state,
          ordinal: i,
          currentLabel: instances[i].name,
          // Invariant: a projected running/paused remaining is > zero.
          remaining: remaining,
          totalRemaining: remaining +
              _detourRemaining(_futureRemaining(i + 1), slot),
          totalPlanned: planned,
          late: late,
          suspendedOrdinal: suspendedOrdinal,
          suspendedRemaining: suspendedRemaining,
        );
    }
  }

  /// Total-remaining under a wall detour: the wall's own remainder plus
  /// what it interrupted (and the plan behind it) — the honest "how much
  /// is left" while a detour runs.
  Duration _detourRemaining(Duration behind, _Suspend? slot) {
    if (_activeWall == null && slot == null) return behind;
    final wallMs = _activeWall == null ? 0 : _effectiveMs(_activeWall!);
    final saveMs = (slot == null || slot.finished)
        ? 0
        : slot.remainingMs + _futureRemaining(slot.ordinal! + 1).inMilliseconds;
    return behind + Duration(milliseconds: wallMs + saveMs);
  }

  Duration _futureRemaining(int fromOrdinal) {
    var ms = 0;
    for (var j = fromOrdinal; j < instances.length; j++) {
      ms += _effectiveMs(j);
    }
    return Duration(milliseconds: ms);
  }
}

/// Internal cursor: which instance the run is on and how its elapsed time is
/// anchored. `accumulatedMs` is banked elapsed time before `anchorMs` (for
/// paused: the frozen elapsed; for awaitingAdvance/notStarted: unused).
class _Cursor {
  const _Cursor(this.state, this.ordinal, this.accumulatedMs, this.anchorMs);

  final SessionState state;
  final int? ordinal;
  final int accumulatedMs;
  final int anchorMs;
}

/// Result of projecting a cursor: the new cursor plus the `done` events the
/// projection's zero-crossings produced (empty for non-running states).
class _Projection {
  const _Projection(
    this.cursor,
    this.events,
    this.marked,
    this.fired,
    this.lateWalls,
    this.slot,
    this.activeWall,
  );

  final _Cursor cursor;
  final List<InstanceEnded> events;

  /// v2 P1.3/1.4 — the run state as the simulation left it. PROJECTION
  /// IS PURE (snapshot must not mutate); only _settleAt applies these.
  final Set<int> marked;
  final Set<int> fired;
  final Set<int> lateWalls;
  final _Suspend? slot;
  final int? activeWall;
}

/// v2 P1.4 — a wall-detour suspension: what the wall interrupted. A
/// mid-flight item freezes at [remainingMs] in [state] and RESUMES at
/// those values when the wall completes; [finished] means the run was
/// already complete when the wall took over (resume → fresh).
class _Suspend {
  const _Suspend.item(this.ordinal, this.remainingMs, this.state)
    : finished = false;
  const _Suspend.finished()
    : ordinal = null,
      remainingMs = 0,
      state = SessionState.notStarted,
      finished = true;

  final int? ordinal;
  final int remainingMs;
  final SessionState state;
  final bool finished;
}

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerSnapshot &&
          other.state == state &&
          other.ordinal == ordinal &&
          other.currentLabel == currentLabel &&
          other.remaining == remaining &&
          other.totalRemaining == totalRemaining &&
          other.totalPlanned == totalPlanned;

  @override
  int get hashCode => Object.hash(
    state,
    ordinal,
    currentLabel,
    remaining,
    totalRemaining,
    totalPlanned,
  );

  @override
  String toString() =>
      'TimerSnapshot($state, ordinal=${ordinal ?? '-'}, '
      '${currentLabel ?? '<unnamed>'}, remaining=$remaining, '
      'totalRemaining=$totalRemaining, totalPlanned=$totalPlanned)';
}

/// The timer execution engine: plays a flattened schedule as a run with
/// wall-clock anchors, emitting one [InstanceEnded] per instance end
/// (zero-crossing → `done`; force-end before zero → `skipped`).
class TimerSession {
  TimerSession(this.instances, {required this.clock, required this.sink});

  /// The flattened schedule to play; [IntervalInstance.ordinal] == index.
  final List<IntervalInstance> instances;

  /// Injected time source; the session never reads the OS clock.
  final Clock clock;

  /// Injected sink for [InstanceEnded] events.
  final EventSink<InstanceEnded> sink;

  static const _Cursor _fresh = _Cursor(SessionState.notStarted, null, 0, 0);

  _Cursor _cursor = _fresh;

  /// Per-run ephemeral duration adjustments (tweaks #7): ordinal → added
  /// milliseconds. NOT part of the saved definition — they live on this
  /// session only, and an instance plays at its ADJUSTED length however
  /// the run reaches it (including jumpTo's fresh restart).
  final Map<int, int> _adjustMs = <int, int>{};

  /// The instance's length for THIS run: planned + the ephemeral adjust.
  int _effectiveMs(int ordinal) =>
      instances[ordinal].durationSeconds * 1000 + (_adjustMs[ordinal] ?? 0);

  /// Starts the run on instance 0 (accumulated=0, anchor=now). Returns true
  /// only from [SessionState.notStarted] with a non-empty schedule; an empty
  /// schedule stays notStarted and returns false.
  bool start() {
    final nowMs = _settleAtClock();
    if (_cursor.state != SessionState.notStarted || instances.isEmpty) {
      return false;
    }
    _cursor = _Cursor(SessionState.running, 0, 0, nowMs);
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
      sink.emit(
        InstanceEnded(
          ordinal: i,
          defId: instances[i].defId,
          terminal: TerminalState.done,
          endedAt: DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
        ),
      );
      _adjustMs.remove(i); // absorbed by the completion
      if (!instances[i].autoFinish) {
        _cursor = _Cursor(SessionState.awaitingAdvance, i, 0, nowMs);
      } else if (i == instances.length - 1) {
        _cursor = _fresh;
      } else {
        _cursor = _Cursor(
          state == SessionState.paused
              ? SessionState.paused
              : SessionState.running,
          i + 1,
          0,
          nowMs,
        );
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
    final midRun =
        state == SessionState.running ||
        state == SessionState.paused ||
        state == SessionState.awaitingAdvance;
    if (midRun) {
      final current = _cursor.ordinal!;
      if (state != SessionState.awaitingAdvance) {
        _emitSkipped(current, nowMs);
      }
      if (ordinal > current) {
        for (var j = current + 1; j < ordinal; j++) {
          _emitSkipped(j, nowMs);
        }
      }
    }
    _cursor = _Cursor(
      state == SessionState.running ? SessionState.running : SessionState.paused,
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
    final nowMs = _settleAtClock();
    if (_cursor.state == SessionState.notStarted) return;
    if (_cursor.state != SessionState.awaitingAdvance) {
      _emitSkipped(_cursor.ordinal!, nowMs);
    }
    _cursor = _fresh;
  }

  /// Projects the cursor at [now] WITHOUT mutating anything and WITHOUT
  /// emitting events. Calling twice with the same [now] gives identical
  /// results and zero side effects.
  TimerSnapshot snapshot(DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    final projection = _project(_cursor, nowMs);
    return _toSnapshot(projection.cursor, nowMs);
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
  }

  void _emitSkipped(int ordinal, int atMs) {
    sink.emit(
      InstanceEnded(
        ordinal: ordinal,
        defId: instances[ordinal].defId,
        terminal: TerminalState.skipped,
        endedAt: DateTime.fromMillisecondsSinceEpoch(atMs, isUtc: true),
      ),
    );
  }

  void _advanceFrom(int lastOrdinal, int nowMs) {
    if (lastOrdinal + 1 >= instances.length) {
      _cursor = _fresh;
    } else {
      _cursor = _Cursor(SessionState.running, lastOrdinal + 1, 0, nowMs);
    }
  }

  /// The projection algorithm. Derives the cursor forward from wall-clock
  /// anchors; cascades auto-finish crossings in one pass; collects the
  /// `done` events the crossings produced.
  _Projection _project(_Cursor cursor, int nowMs) {
    var current = cursor;
    final events = <InstanceEnded>[];
    while (current.state == SessionState.running) {
      final i = current.ordinal!;
      final durationMs = _effectiveMs(i);
      final sinceAnchor = nowMs - current.anchorMs;
      // Backwards clock: clamp, elapsed = accumulated only.
      final elapsed =
          current.accumulatedMs + (sinceAnchor > 0 ? sinceAnchor : 0);
      final remainingMs = durationMs - elapsed;
      if (remainingMs > 0) break; // still running — nothing crosses
      // Zero crossing: the instance ended at this absolute instant...
      final endedAtMs = current.anchorMs + (durationMs - current.accumulatedMs);
      events.add(
        InstanceEnded(
          ordinal: i,
          defId: instances[i].defId,
          terminal: TerminalState.done,
          endedAt: DateTime.fromMillisecondsSinceEpoch(endedAtMs, isUtc: true),
        ),
      );
      if (!instances[i].autoFinish) {
        // Manually complete: hold at exactly zero — the overshoot is
        // ABSORBED; the chain waits for the user to advance.
        current = _Cursor(SessionState.awaitingAdvance, i, 0, endedAtMs);
        break;
      }
      if (i == instances.length - 1) {
        // End of the list: reset immediately; leftover overshoot is
        // discarded (the fresh session shows totalPlanned again).
        current = _fresh;
        break;
      }
      // Auto-finish flows into the next instance anchored at the end time;
      // the loop carries the overshoot across as already-elapsed time.
      current = _Cursor(SessionState.running, i + 1, 0, endedAtMs);
    }
    return _Projection(current, events);
  }

  TimerSnapshot _toSnapshot(_Cursor cursor, int nowMs) {
    final planned = totalPlanned(instances);
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
          totalRemaining: _futureRemaining(i + 1),
          totalPlanned: planned,
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
          totalRemaining: remaining + _futureRemaining(i + 1),
          totalPlanned: planned,
        );
    }
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
  const _Projection(this.cursor, this.events);

  final _Cursor cursor;
  final List<InstanceEnded> events;
}

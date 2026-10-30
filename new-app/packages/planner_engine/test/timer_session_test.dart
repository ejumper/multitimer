import 'package:planner_engine/planner_engine.dart';
import 'package:test/test.dart';

/// Execution state machine tests (P1.2): transition legality, wall-clock
/// anchor derivation, boundary races, auto/manual × first/middle/last, skip
/// and jump semantics, exactly-once terminal events. Virtual time is free —
/// move `clock.current` and call snapshot/settle. Instances are built
/// directly via the [IntervalInstance] constructor (real ordinals/ids come
/// from `flatten`).
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late RecordingSink sink;

  setUp(() {
    clock = FixedClock(t0);
    sink = RecordingSink();
  });

  TimerSession session(List<IntervalInstance> instances) =>
      TimerSession(instances, clock: clock, sink: sink);

  IntervalInstance inst(
    int ordinal, {
    int seconds = 60,
    bool autoFinish = true,
    String? name,
    String defId = 'd',
    String color = '#0055ff',
    String? alert,
  }) => IntervalInstance(
    ordinal: ordinal,
    defId: defId,
    name: name,
    color: color,
    durationSeconds: seconds,
    autoFinish: autoFinish,
    endAlertSoundFile: alert,
  );

  Duration secs(int n) => Duration(seconds: n);

  void warpBy(Duration d) => clock.current = clock.current.add(d);

  // ── Transitions legality matrix ─────────────────────────────────────────

  // Fresh → running on instance 0; totals projected from the schedule.
  test('start_runs_first_instance', () {
    final s = session([inst(0, seconds: 30, name: 'warm'), inst(1, seconds: 45)]);
    expect(s.start(), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 0);
    expect(snap.currentLabel, 'warm');
    expect(snap.remaining, secs(30));
    expect(snap.totalRemaining, secs(75));
    expect(snap.totalPlanned, secs(75));
  });

  // start() only succeeds from notStarted — running and paused refuse it.
  test('start_is_noop_unless_not_started', () {
    final s = session([inst(0), inst(1)]);
    expect(s.start(), isTrue);
    warpBy(secs(10));
    expect(s.start(), isFalse); // already running
    expect(s.snapshot(clock.current).ordinal, 0);
    s.pause();
    expect(s.start(), isFalse); // paused is not notStarted
    expect(s.snapshot(clock.current).state, SessionState.paused);
  });

  // True only from running; false from notStarted, paused, awaitingAdvance.
  test('pause_only_legal_from_running', () {
    expect(session([inst(0)]).pause(), isFalse); // notStarted

    final running = session([inst(0)]);
    running.start();
    warpBy(secs(10));
    expect(running.pause(), isTrue);
    expect(running.snapshot(clock.current).state, SessionState.paused);
    expect(running.pause(), isFalse); // already paused

    final manual = session([inst(0, autoFinish: false)]);
    manual.start();
    warpBy(secs(60)); // zero crossing → awaitingAdvance
    expect(manual.pause(), isFalse);
    expect(manual.snapshot(clock.current).state, SessionState.awaitingAdvance);
  });

  // True only from paused; re-anchors so the paused span consumes nothing.
  test('resume_only_legal_from_paused', () {
    expect(session([inst(0)]).resume(), isFalse); // notStarted

    final s = session([inst(0)]);
    s.start();
    warpBy(secs(10));
    expect(s.resume(), isFalse); // running
    expect(s.pause(), isTrue);
    warpBy(secs(5));
    expect(s.resume(), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.remaining, secs(50)); // 10s banked, the 5s pause consumed none
    expect(s.resume(), isFalse); // running again
  });

  // Legal from running, paused, and awaitingAdvance; illegal from notStarted.
  test('skip_legal_from_running_paused_awaiting', () {
    final fromRunning = session([inst(0), inst(1)]);
    fromRunning.start();
    warpBy(secs(10));
    expect(fromRunning.skipNext(), isTrue);
    expect(fromRunning.snapshot(clock.current).ordinal, 1);

    final fromPaused = session([inst(0), inst(1)]);
    fromPaused.start();
    warpBy(secs(10));
    fromPaused.pause();
    expect(fromPaused.skipNext(), isTrue);
    expect(fromPaused.snapshot(clock.current).ordinal, 1);

    final fromAwaiting = session([inst(0, autoFinish: false), inst(1)]);
    fromAwaiting.start();
    warpBy(secs(60)); // zero crossing → awaitingAdvance
    expect(fromAwaiting.skipNext(), isTrue);
    expect(fromAwaiting.snapshot(clock.current).ordinal, 1);

    expect(session([inst(0), inst(1)]).skipNext(), isFalse); // notStarted
  });

  // Same-ordinal jump force-ends the previous attempt and restarts fresh;
  // from awaitingAdvance it parks paused-ready (the done was already logged).
  test('jump_to_same_ordinal_restarts_instance', () {
    final s = session([inst(0), inst(1), inst(2)]);
    s.start();
    s.jumpTo(1);
    warpBy(secs(20));
    expect(s.jumpTo(1), isTrue); // restart: previous attempt force-ends
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(60)); // fresh full duration
    expect(
      sink.events.map((e) => e.terminal),
      [TerminalState.skipped, TerminalState.skipped],
    );

    final manual = session([inst(0, autoFinish: false)]);
    manual.start();
    warpBy(secs(60));
    expect(manual.jumpTo(0), isTrue);
    final held = manual.snapshot(clock.current);
    expect(held.state, SessionState.paused);
    expect(held.remaining, secs(60));
    expect(sink.events.length, 3); // 2 skips + the manual's done, no duplicate
  });

  // Mid-run reset → fresh notStarted; the non-zeroed current ends skipped;
  // a second reset is a no-op with no extra events.
  test('reset_returns_to_fresh_not_started', () {
    final s = session([inst(0), inst(1)]);
    s.start();
    warpBy(secs(30));
    s.reset();
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.notStarted);
    expect(snap.ordinal, isNull);
    expect(snap.currentLabel, isNull);
    expect(snap.remaining, isNull);
    expect(snap.totalRemaining, snap.totalPlanned);
    expect(sink.events.single.terminal, TerminalState.skipped);
    s.reset(); // no-op from notStarted
    expect(sink.events.length, 1);
    expect(s.start(), isTrue); // fresh again
  });

  // Empty schedule: start refuses; snapshot shows zero planned.
  test('start_on_empty_timer_is_noop', () {
    final s = session([]);
    expect(s.start(), isFalse);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.notStarted);
    expect(snap.totalRemaining, Duration.zero);
    expect(snap.totalPlanned, Duration.zero);
  });

  // ── Anchors and drift ───────────────────────────────────────────────────

  // Remaining is exactly derived from anchors, however far the clock warps.
  test('no_drift_over_long_warp', () {
    final s = session([inst(0, seconds: 3600)]);
    s.start();
    warpBy(const Duration(minutes: 30));
    expect(s.snapshot(clock.current).remaining, const Duration(minutes: 30));
    warpBy(const Duration(minutes: 29, seconds: 59));
    final snap = s.snapshot(clock.current);
    expect(snap.remaining, secs(1));
    expect(snap.totalRemaining, secs(1)); // invariant: running remaining > 0
  });

  // A backwards clock clamps: elapsed never goes negative, never overflows.
  test('backwards_clock_clamps_to_sane_state', () {
    final s = session([inst(0)]);
    s.start();
    warpBy(const Duration(minutes: -5)); // clock jumped before the anchor
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.remaining, secs(60)); // clamped: full duration, not "more"
    s.settle(clock.current);
    expect(sink.events, isEmpty);
  });

  // A 2h suspension across 3×30m auto instances: the projection runs past
  // the end of the list → fresh notStarted, all three ends logged done.
  test('suspension_warp_past_several_auto_instances', () {
    final s = session([
      inst(0, seconds: 1800),
      inst(1, seconds: 1800),
      inst(2, seconds: 1800),
    ]);
    s.start();
    warpBy(const Duration(hours: 2));
    s.settle(clock.current);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.notStarted); // end resets immediately
    expect(snap.totalRemaining, snap.totalPlanned);
    expect(sink.events.map((e) => e.ordinal), [0, 1, 2]);
    expect(sink.events.every((e) => e.terminal == TerminalState.done), isTrue);
  });

  // Paused remaining is frozen; 10h of wall time later it is untouched.
  test('paused_state_survives_time_warp', () {
    final s = session([inst(0, seconds: 1800)]);
    s.start();
    warpBy(const Duration(minutes: 10));
    expect(s.pause(), isTrue);
    warpBy(const Duration(hours: 10));
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.paused);
    expect(snap.remaining, const Duration(minutes: 20));
    expect(sink.events, isEmpty);
  });

  // Snapshot: identical results for identical now, no events, no mutation —
  // it can even *see* a future crossing without causing it.
  test('snapshot_is_pure_and_idempotent', () {
    final s = session([inst(0)]); // 60s auto
    s.start();
    warpBy(secs(30));
    final now = clock.current;
    final a = s.snapshot(now);
    final b = s.snapshot(now);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(sink.events, isEmpty);

    warpBy(secs(60)); // now at +90s: the single 60s instance is already over
    final late = s.snapshot(clock.current);
    expect(late.state, SessionState.notStarted); // projected finish...
    expect(sink.events, isEmpty); // ...but nothing was emitted
    // ...and the cursor is untouched: the earlier `now` still projects on.
    expect(s.snapshot(now).remaining, secs(30));
    s.settle(clock.current); // now the crossing really applies
    expect(sink.events.single.terminal, TerminalState.done);
  });

  // ── Boundary races ──────────────────────────────────────────────────────

  // At t−1ms the instance is still running; the crossing fires AT t.
  test('finish_armed_only_in_future', () {
    final s = session([inst(0, autoFinish: false)]);
    s.start();
    warpBy(secs(60) - const Duration(milliseconds: 1));
    var snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.remaining, const Duration(milliseconds: 1));
    s.settle(clock.current);
    expect(sink.events, isEmpty); // not yet — 1ms still on the clock

    warpBy(const Duration(milliseconds: 1)); // exactly t
    snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.awaitingAdvance); // fires at t, not before
    expect(snap.remaining, Duration.zero);
    s.settle(clock.current);
    expect(sink.events.single.endedAt, t0.add(secs(60)));
  });

  // pause() AT the zero moment: the settle inside pause() crosses first, so
  // pause returns false and the session is awaitingAdvance with done logged.
  test('last_instant_pause_crossing_wins', () {
    final s = session([inst(0, autoFinish: false)]);
    s.start();
    warpBy(secs(60));
    expect(s.pause(), isFalse);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.awaitingAdvance);
    expect(snap.remaining, Duration.zero);
    expect(sink.events.single.terminal, TerminalState.done);
    expect(sink.events.single.endedAt, t0.add(secs(60)));
  });

  // One millisecond before zero: pause succeeds and freezes that last ms.
  test('pause_at_t_minus_1ms_freezes_last_instant', () {
    final s = session([inst(0, autoFinish: false)]);
    s.start();
    warpBy(secs(60) - const Duration(milliseconds: 1));
    expect(s.pause(), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.paused);
    expect(snap.remaining, const Duration(milliseconds: 1));
    expect(sink.events, isEmpty);
    warpBy(secs(5)); // staying paused never lets the frozen ms slip away
    expect(s.snapshot(clock.current).remaining, const Duration(milliseconds: 1));
  });

  // A late pause lands on the state that EXISTS after the crossing: the
  // auto instance flowed over and the NEXT one is what gets paused.
  test('late_pause_after_autofinish_pauses_next', () {
    final s = session([inst(0), inst(1)]); // two 60s auto
    s.start();
    warpBy(secs(61));
    expect(s.pause(), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.paused);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(59));
    expect(sink.events.single.ordinal, 0);
    expect(sink.events.single.terminal, TerminalState.done);
  });

  // After the FINAL auto crossing the session is fresh — pause is a no-op.
  test('pause_after_last_autofinish_is_noop_on_fresh', () {
    final s = session([inst(0)]);
    s.start();
    warpBy(secs(61));
    expect(s.pause(), isFalse); // the final crossing reset to fresh
    expect(s.snapshot(clock.current).state, SessionState.notStarted);
    expect(sink.events.single.terminal, TerminalState.done);
  });

  // A manually-complete instance at zero keeps holding at zero through
  // repeated failed pause attempts; done was emitted exactly once.
  test('manual_at_zero_pause_keeps_awaiting_advance', () {
    final s = session([inst(0, autoFinish: false), inst(1)]);
    s.start();
    warpBy(secs(60));
    expect(s.pause(), isFalse);
    expect(s.pause(), isFalse); // still holding at zero
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.awaitingAdvance);
    expect(snap.ordinal, 0);
    expect(snap.remaining, Duration.zero);
    expect(sink.events.length, 1); // done emitted once, at the crossing
  });

  // ── Auto/manual × first/middle/last ─────────────────────────────────────

  // Manual first instance holds at zero; overshoot is absorbed, not borrowed.
  test('manual_first_instance_holds_at_zero', () {
    final s = session([
      inst(0, autoFinish: false, name: 'hold'),
      inst(1, seconds: 60),
      inst(2, seconds: 60),
    ]);
    s.start();
    warpBy(secs(90)); // ord0 zeroed at +60, has been holding since
    s.settle(clock.current);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.awaitingAdvance);
    expect(snap.ordinal, 0);
    expect(snap.currentLabel, 'hold');
    expect(snap.remaining, Duration.zero);
    expect(snap.totalRemaining, secs(120)); // sum of #1 and #2 only
  });

  // Manual middle instance holds at zero, then skipNext advances to a full
  // running next instance (no overshoot leaks into it).
  test('manual_middle_instance_holds_then_advances', () {
    final s = session([inst(0), inst(1, autoFinish: false), inst(2)]);
    s.start();
    warpBy(secs(130)); // ord0 done at +60; ord1 zeroed at +120, holding
    s.settle(clock.current);
    expect(s.snapshot(clock.current).state, SessionState.awaitingAdvance);
    expect(s.snapshot(clock.current).ordinal, 1);
    expect(s.skipNext(), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 2);
    expect(snap.remaining, secs(60)); // full — overshoot stayed absorbed
    expect(sink.events.map((e) => e.ordinal), [0, 1]);
    expect(sink.events.every((e) => e.terminal == TerminalState.done), isTrue);
  });

  // Manual LAST instance holds at zero; advancing past the end resets fresh.
  test('manual_last_instance_awaits_then_resets', () {
    final s = session([inst(0), inst(1, autoFinish: false)]);
    s.start();
    warpBy(secs(150)); // ord0 done at +60; ord1 zeroed at +120, holding
    s.settle(clock.current);
    expect(s.snapshot(clock.current).state, SessionState.awaitingAdvance);
    expect(s.skipNext(), isTrue); // advance past the last → fresh
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.notStarted);
    expect(snap.totalRemaining, snap.totalPlanned);
    expect(sink.events.length, 2); // done ord0, done ord1 — nothing extra
  });

  // Auto middle instance flows automatically; overshoot carries across.
  test('auto_middle_instance_flows_automatically', () {
    final s = session([inst(0), inst(1)]);
    s.start();
    warpBy(secs(90));
    s.settle(clock.current);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(30)); // 60s instance minus 30s overshoot
    expect(sink.events.map((e) => e.ordinal), [0]);
  });

  // Auto LAST instance: the final crossing resets immediately, overshoot
  // discarded, both ends logged with their true end moments.
  test('auto_last_instance_resets_immediately', () {
    final s = session([inst(0), inst(1, seconds: 30)]);
    s.start();
    warpBy(secs(100));
    s.settle(clock.current);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.notStarted);
    expect(snap.totalRemaining, snap.totalPlanned);
    expect(
      sink.events.map((e) => e.endedAt),
      [t0.add(secs(60)), t0.add(secs(90))],
    );
  });

  // auto → manual → auto: the chain cascades over the first boundary, the
  // manual instance ABSORBS its overshoot and holds, ord2 never runs.
  test('mixed_chain_manual_absorbs_overshoot', () {
    final s = session([inst(0), inst(1, autoFinish: false), inst(2)]);
    s.start();
    warpBy(secs(250));
    s.settle(clock.current);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.awaitingAdvance);
    expect(snap.ordinal, 1);
    expect(snap.remaining, Duration.zero);
    expect(snap.totalRemaining, secs(60)); // ord2 untouched — not cascaded
    expect(sink.events.map((e) => e.ordinal), [0, 1]);
  });

  // ── Skip during each state ──────────────────────────────────────────────

  // Running skip: current ends skipped (with its identity), next starts full.
  test('skip_from_running_marks_skipped', () {
    final s = session([inst(0, defId: 'a'), inst(1, defId: 'b')]);
    s.start();
    warpBy(secs(20));
    expect(s.skipNext(), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(60)); // next starts fresh
    final e = sink.events.single;
    expect(e.ordinal, 0);
    expect(e.defId, 'a');
    expect(e.terminal, TerminalState.skipped);
    expect(e.endedAt, clock.current); // ended now — skip is the end cause
  });

  // Paused skip: same force-end rule, frozen partial attempt logged skipped.
  test('skip_from_paused_marks_skipped', () {
    final s = session([inst(0), inst(1)]);
    s.start();
    warpBy(secs(40));
    s.pause();
    expect(s.skipNext(), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(60));
    expect(sink.events.single.terminal, TerminalState.skipped);
    expect(sink.events.single.ordinal, 0);
  });

  // AwaitingAdvance skip: the done was already emitted at the zero-crossing;
  // advancing must NOT emit a second event for the same occurrence.
  test('skip_from_awaiting_advance_emits_no_duplicate', () {
    final s = session([inst(0, autoFinish: false), inst(1)]);
    s.start();
    warpBy(secs(60));
    expect(s.skipNext(), isTrue); // settle crossed first → awaitingAdvance
    expect(sink.events.length, 1);
    expect(sink.events.single.terminal, TerminalState.done);
    expect(s.snapshot(clock.current).ordinal, 1);
  });

  // Skipping the LAST running instance ends it skipped and resets fresh.
  test('skip_on_last_instance_finishes_and_resets', () {
    final s = session([inst(0), inst(1)]);
    s.start();
    s.skipNext(); // burn ord0 immediately
    warpBy(secs(15));
    expect(s.skipNext(), isTrue); // skipping the last → fresh notStarted
    expect(s.snapshot(clock.current).state, SessionState.notStarted);
    expect(
      sink.events.map((e) => e.terminal),
      [TerminalState.skipped, TerminalState.skipped],
    );
  });

  // ── Jump during each state ──────────────────────────────────────────────

  // A running jump keeps running at the target, full remaining.
  test('jump_from_running_starts_target_running', () {
    final s = session([inst(0), inst(1), inst(2)]);
    s.start();
    warpBy(secs(10));
    expect(s.jumpTo(1), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(60)); // the abandoned time buys nothing
    expect(sink.events.map((e) => e.ordinal), [0]); // abandoned attempt
  });

  // A paused jump parks the target paused-ready: full remaining, no time.
  test('jump_from_paused_sits_target_paused_ready', () {
    final s = session([inst(0), inst(1), inst(2)]);
    s.start();
    warpBy(secs(10));
    s.pause();
    expect(s.jumpTo(1), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.paused);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(60)); // accumulated 0 = full duration
    expect(snap.totalRemaining, secs(120));
  });

  // A jump from notStarted positions without events — nothing ever ran.
  test('jump_from_not_started_positions_without_events', () {
    final s = session([inst(0), inst(1), inst(2)]);
    expect(s.jumpTo(2), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.paused);
    expect(snap.ordinal, 2);
    expect(snap.remaining, secs(60));
    expect(sink.events, isEmpty);
  });

  // Forward mid-run jump: the abandoned current AND every never-ran
  // in-between instance are logged skipped; the target starts running.
  test('jump_forward_skips_intermediates_logged_skipped', () {
    final s = session([for (var i = 0; i < 5; i++) inst(i)]);
    s.start();
    warpBy(secs(10));
    expect(s.jumpTo(3), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 3);
    expect(snap.remaining, secs(60));
    expect(sink.events.map((e) => e.ordinal), [0, 1, 2]);
    expect(sink.events.every((e) => e.terminal == TerminalState.skipped), isTrue);
  });

  // Backward jump restarts the earlier instance; the abandoned current is
  // logged skipped, but in-between instances emit NOTHING on the way back.
  test('jump_backward_restarts_earlier_instance', () {
    final s = session([for (var i = 0; i < 5; i++) inst(i)]);
    s.start();
    s.jumpTo(3);
    warpBy(secs(10));
    expect(s.jumpTo(1), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(60));
    // ord0..ord2 skipped by the initial forward jump (current + never-ran
    // intermediates), ord3 by the backward restart; the backward jump's own
    // in-between stretch (ord2 again) emits NOTHING.
    expect(sink.events.map((e) => e.ordinal), [0, 1, 2, 3]);
  });

  // Out-of-range (and empty-schedule) jumps refuse and change nothing.
  test('jump_out_of_range_is_noop', () {
    final s = session([inst(0), inst(1)]);
    s.start();
    warpBy(secs(10));
    expect(s.jumpTo(-1), isFalse);
    expect(s.jumpTo(2), isFalse);
    expect(s.jumpTo(99), isFalse);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 0);
    expect(snap.remaining, secs(50)); // untouched
    expect(sink.events, isEmpty);
    expect(session([]).jumpTo(0), isFalse);
  });

  // ── Empty / 1-interval schedules ────────────────────────────────────────

  // Single auto instance: runs to zero, logs done at its true end, resets.
  test('single_instance_autofinish_runs_then_resets', () {
    final s = session([inst(0)]);
    s.start();
    warpBy(secs(59));
    s.settle(clock.current);
    expect(s.snapshot(clock.current).remaining, secs(1));
    warpBy(secs(1));
    s.settle(clock.current);
    expect(s.snapshot(clock.current).state, SessionState.notStarted);
    expect(sink.events.single.endedAt, t0.add(secs(60)));
  });

  // Single manual instance: holds at zero, then advancing (no next) resets.
  test('single_instance_manual_holds_then_resets_on_advance', () {
    final s = session([inst(0, autoFinish: false)]);
    s.start();
    warpBy(secs(90));
    s.settle(clock.current);
    expect(s.snapshot(clock.current).state, SessionState.awaitingAdvance);
    expect(s.skipNext(), isTrue); // no next → fresh
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.notStarted);
    expect(snap.totalRemaining, snap.totalPlanned);
    expect(sink.events.length, 1); // only the done at zero
  });

  // Empty schedule: snapshot is a well-formed fresh projection of nothing.
  test('empty_timer_snapshots_not_started_with_zero_planned', () {
    final s = session([]);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.notStarted);
    expect(snap.ordinal, isNull);
    expect(snap.currentLabel, isNull);
    expect(snap.remaining, isNull);
    expect(snap.totalRemaining, Duration.zero);
    expect(snap.totalPlanned, Duration.zero);
    s.reset(); // no-op
    s.settle(clock.current);
    expect(sink.events, isEmpty);
  });

  // ── Events exactly-once ─────────────────────────────────────────────────

  // Settling repeatedly at the same instant never re-emits a crossing.
  test('instance_end_emits_exactly_once', () {
    final s = session([inst(0), inst(1)]);
    s.start();
    warpBy(secs(90)); // past ord0's zero, mid-way through ord1
    s.settle(clock.current);
    s.settle(clock.current); // same late instant again: nothing new crosses
    s.settle(clock.current);
    expect(sink.events.map((e) => e.ordinal), [0]);
    warpBy(secs(60)); // past ord1's zero too
    s.settle(clock.current);
    s.settle(clock.current);
    expect(sink.events.map((e) => e.ordinal), [0, 1]); // once per end
  });

  // Events carry the instance's identity and the TRUE end moment — not the
  // (much later) settle time.
  test('terminal_events_carry_ordinal_defid_and_time', () {
    final s = session([inst(0, defId: 'alpha'), inst(1, defId: 'beta')]);
    s.start();
    warpBy(secs(90)); // settle happens at +90s...
    s.settle(clock.current);
    final e = sink.events.single;
    expect(e.ordinal, 0);
    expect(e.defId, 'alpha');
    expect(e.terminal, TerminalState.done);
    expect(e.endedAt, t0.add(secs(60))); // ...but endedAt is the real end
    expect(e.endedAt.isBefore(clock.current), isTrue);
  });

  // Mid-run reset force-ends the non-zeroed current as skipped, ended now.
  test('reset_mid_run_ends_current_as_skipped', () {
    final s = session([inst(0), inst(1)]);
    s.start();
    warpBy(secs(30));
    s.reset();
    final e = sink.events.single;
    expect(e.ordinal, 0);
    expect(e.terminal, TerminalState.skipped);
    expect(e.endedAt, clock.current);
    expect(s.snapshot(clock.current).state, SessionState.notStarted);
  });
  // ── Tweaks #7: adjustCurrent — ephemeral +/- on the current instance ──

  // Running: a positive delta extends the remaining, a negative shrinks
  // it; the definition is untouched (only the cursor shifts).
  test('adjust_running_extends_and_shrinks_remaining', () {
    final s = session([inst(0, seconds: 60), inst(1, seconds: 60)]);
    s.start();
    warpBy(secs(10)); // 50s left
    expect(s.adjustCurrent(20), isTrue);
    expect(s.snapshot(clock.current).remaining, secs(70));
    expect(s.adjustCurrent(-30), isTrue);
    expect(s.snapshot(clock.current).remaining, secs(40));
    expect(s.snapshot(clock.current).state, SessionState.running);
  });

  // Paused: the adjustment lands on the frozen remaining; still paused.
  test('adjust_paused_keeps_paused', () {
    final s = session([inst(0, seconds: 60), inst(1, seconds: 60)]);
    s.start();
    warpBy(secs(10));
    s.pause();
    expect(s.adjustCurrent(5), isTrue);
    expect(s.snapshot(clock.current).remaining, secs(55));
    expect(s.snapshot(clock.current).state, SessionState.paused);
  });

  // Clamp on a running MANUAL instance: exactly one `done` at now,
  // limbo (awaitingAdvance), remaining zero. The excess is discarded.
  test('adjust_clamp_manual_lands_in_limbo', () {
    final s = session([inst(0, seconds: 60, autoFinish: false), inst(1, seconds: 60)]);
    s.start();
    warpBy(secs(10)); // 50s left
    expect(s.adjustCurrent(-3600), isTrue); // way more than remains
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.awaitingAdvance);
    expect(snap.remaining, secs(0));
    expect(sink.events.length, 1);
    expect(sink.events.single.terminal, TerminalState.done);
    expect(sink.events.single.endedAt, clock.current);
  });

  // Clamp on a running AUTO instance: `done` at now, the next instance
  // runs with FULL remaining — the overshoot never cascades.
  test('adjust_clamp_auto_advances_with_full_remaining', () {
    final s = session([inst(0, seconds: 60), inst(1, seconds: 45)]);
    s.start();
    warpBy(secs(10));
    expect(s.adjustCurrent(-3600), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(45));
    expect(sink.events.length, 1);
  });

  // Clamp while PAUSED: the run stays paused — the next instance parks
  // full remaining (the jumpTo rule), never silently resumes.
  test('adjust_clamp_while_paused_stays_paused', () {
    final s = session([inst(0, seconds: 60), inst(1, seconds: 45)]);
    s.start();
    warpBy(secs(10));
    s.pause();
    expect(s.adjustCurrent(-3600), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.paused);
    expect(snap.ordinal, 1);
    expect(snap.remaining, secs(45));
  });

  // Clamp on the LAST auto instance: the run resets to fresh.
  test('adjust_clamp_last_auto_resets_run', () {
    final s = session([inst(0, seconds: 60)]);
    s.start();
    expect(s.adjustCurrent(-3600), isTrue);
    expect(s.snapshot(clock.current).state, SessionState.notStarted);
    expect(sink.events.length, 1);
  });

  // Limbo promotion: adding time pulls the held instance back to running
  // with EXACTLY that much remaining (its planned duration is spent).
  test('adjust_adding_time_promotes_limbo_to_running', () {
    final s = session([inst(0, seconds: 60, autoFinish: false), inst(1, seconds: 60)]);
    s.start();
    warpBy(secs(70)); // manual instance holds at zero
    expect(s.snapshot(clock.current).state, SessionState.awaitingAdvance);
    expect(s.adjustCurrent(30), isTrue);
    final snap = s.snapshot(clock.current);
    expect(snap.state, SessionState.running);
    expect(snap.ordinal, 0);
    expect(snap.remaining, secs(30));
  });

  // Limbo + removal is a no-op — there is nothing left to take.
  test('adjust_removing_from_limbo_is_noop', () {
    final s = session([inst(0, seconds: 60, autoFinish: false), inst(1, seconds: 60)]);
    s.start();
    warpBy(secs(70));
    expect(s.adjustCurrent(-30), isFalse);
    expect(s.snapshot(clock.current).state, SessionState.awaitingAdvance);
  });

  // notStarted and zero deltas are no-ops.
  test('adjust_requires_a_live_instance', () {
    final s = session([inst(0, seconds: 60)]);
    expect(s.adjustCurrent(10), isFalse);
    s.start();
    expect(s.adjustCurrent(0), isFalse);
    expect(s.snapshot(clock.current).remaining, secs(60));
  });

  // The adjustment survives pause/resume and jump-away-and-back (it lives
  // on the run's cursor — ephemeral, but for THIS run).
  test('adjust_survives_pause_resume_and_jump', () {
    final s = session([inst(0, seconds: 60), inst(1, seconds: 60)]);
    s.start();
    s.adjustCurrent(60); // +1 min on instance 0
    s.pause();
    s.resume();
    s.jumpTo(1);
    s.jumpTo(0);
    expect(s.snapshot(clock.current).remaining, secs(120));
    expect(s.snapshot(clock.current).state, SessionState.running);
  });
  // Tweaks #7 bugfix: adjustments are per-RUN — reset (and a completed
  // run's next start) replays the SAVED durations, never the adjusted
  // ones.
  test('reset_clears_run_adjustments', () {
    final s = session([inst(0, seconds: 5), inst(1, seconds: 5)]);
    s.start();
    s.adjustCurrent(10); // +10s on the 5s instance
    expect(s.snapshot(clock.current).remaining, secs(15));
    s.reset();
    s.start();
    expect(s.snapshot(clock.current).remaining, secs(5));
    expect(s.snapshot(clock.current).totalPlanned, secs(10));
  });

  test('fresh_run_after_completion_replays_planned', () {
    final s = session([inst(0, seconds: 5)]);
    s.start();
    s.adjustCurrent(10);
    s.adjustCurrent(-3600); // clamp ends the run (last auto -> fresh)
    expect(s.snapshot(clock.current).state, SessionState.notStarted);
    s.start();
    expect(s.snapshot(clock.current).remaining, secs(5));
  });
}

/// Mutable test clock: virtual time is free — assign [current] directly.
class FixedClock implements Clock {
  FixedClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;

}

/// Collects every [InstanceEnded] the session emits, in order.
class RecordingSink implements EventSink<InstanceEnded> {
  final List<InstanceEnded> events = [];

  @override
  void emit(InstanceEnded event) => events.add(event);

}

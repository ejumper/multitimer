import 'dart:convert';

import 'package:drift/native.dart';
import 'package:planner_engine/planner_engine.dart';
import 'package:test/test.dart';

/// Event-consumption layer tests (P1.4): end-alert decisions (fire at zero
/// for BOTH finish methods, never on skip, sound resolution) and terminal
/// run-log persistence (`run.terminal` entries, caller-supplied timestamps,
/// flush idempotence). Alerts are observed through a recording sink; run-log
/// entries through a real in-memory drift store — no dart:io anywhere.
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late RecordingSink<PlayAlert> alerts;

  setUp(() {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);
    alerts = RecordingSink<PlayAlert>();
  });

  tearDown(() => store.close());

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

  RunEventProcessor processor(
    List<IntervalInstance> instances, {
    List<String> listing = const ['a.mp3', 'b.mp3', 'zz.mp3'],
    String timerName = 'Day chain',
  }) => RunEventProcessor(
    instances: instances,
    store: store,
    timerName: timerName,
    soundDirectoryListing: () => listing,
    alertSink: alerts,
  );

  /// Wires a real [TimerSession] whose sink is a fresh [RunEventProcessor]
  /// — the app-side wiring under test — tee-ed into a recorder so the
  /// [InstanceEnded] stream is observable without changing behavior (the
  /// processor still sees every event synchronously).
  ({
    TimerSession session,
    RunEventProcessor processor,
    RecordingSink<InstanceEnded> ended,
  })
  wired(
    List<IntervalInstance> instances, {
    List<String> listing = const ['a.mp3', 'b.mp3', 'zz.mp3'],
    String timerName = 'Day chain',
  }) {
    final p = processor(instances, listing: listing, timerName: timerName);
    final ended = RecordingSink<InstanceEnded>.of(p);
    return (
      session: TimerSession(instances, clock: clock, sink: ended),
      processor: p,
      ended: ended,
    );
  }

  Duration secs(int n) => Duration(seconds: n);

  void warpBy(Duration d) => clock.current = clock.current.add(d);

  // ── Alert decision ─────────────────────────────────────────────────────

  // An auto-finish instance crossing zero alerts once.
  test('alert_fires_at_zero_for_auto_finish', () {
    final w = wired([inst(0, seconds: 60, alert: 'a.mp3')]);
    expect(w.session.start(), isTrue);
    warpBy(secs(70));
    w.session.settle(clock.current);
    expect(alerts.events, [
      PlayAlert(
        soundFile: 'a.mp3',
        timerName: 'Day chain',
        intervalName: null,
        ordinal: 0,
      ),
    ]);
  });

  // A manually-complete instance reaching zero alerts too (holding at zero
  // is the user's problem, the END already happened).
  test('alert_fires_at_zero_for_manually_complete', () {
    final w = wired([
      inst(0, seconds: 60, autoFinish: false, alert: 'a.mp3'),
      inst(1),
    ]);
    expect(w.session.start(), isTrue);
    warpBy(secs(90)); // zeroed at +60, holding since
    w.session.settle(clock.current);
    expect(
      w.session.snapshot(clock.current).state,
      SessionState.awaitingAdvance,
    );
    expect(alerts.events.single.soundFile, 'a.mp3');
    expect(alerts.events.single.ordinal, 0);
  });

  // Skipped ≠ alerted: force-ending BEFORE zero never alerts, however the
  // skip happens.
  test('no_alert_on_skip_before_zero', () {
    final w = wired([
      inst(0, seconds: 60, alert: 'a.mp3'),
      inst(1, alert: 'b.mp3'),
    ]);
    w.session.start();
    warpBy(secs(20));
    expect(w.session.skipNext(), isTrue); // ord0 ends skipped, not done
    expect(alerts.events, isEmpty);
  });

  // Reaching zero without a configured sound is silent — done, but no alert.
  test('no_alert_without_configured_sound', () {
    final w = wired([inst(0, seconds: 60, alert: null)]);
    w.session.start();
    warpBy(secs(60));
    w.session.settle(clock.current);
    expect(alerts.events, isEmpty);
  });

  // The alert carries the RESOLVED sound file plus the labels the app needs
  // to phrase the notification.
  test('alert_carries_resolved_sound_and_labels', () {
    final w = wired(
      [inst(0, seconds: 60, name: 'stretch', alert: 'bell.mp3')],
      listing: ['bell.mp3', 'gong.wav'],
      timerName: 'Morning chain',
    );
    w.session.start();
    warpBy(secs(60));
    w.session.settle(clock.current);
    expect(
      alerts.events.single,
      const PlayAlert(
        soundFile: 'bell.mp3',
        timerName: 'Morning chain',
        intervalName: 'stretch',
        ordinal: 0,
      ),
    );
  });

  // Advancing a held-at-zero manual instance must not re-alert: the alert
  // belongs to the zero crossing, not to the advance.
  test('manual_zero_alerts_once_not_on_advance', () {
    final w = wired([
      inst(0, seconds: 60, autoFinish: false, alert: 'a.mp3'),
      inst(1, seconds: 60, alert: 'b.mp3'),
    ]);
    w.session.start();
    warpBy(secs(60)); // ord0 zeroed → awaitingAdvance, alert fired
    w.session.settle(clock.current);
    expect(alerts.events.map((a) => a.ordinal), [0]);
    expect(w.session.skipNext(), isTrue); // advances to ord1 running
    w.session.settle(clock.current);
    expect(alerts.events.map((a) => a.ordinal), [0]); // nothing extra
  });

  // Mid-run reset ends the current instance skipped → no alert at all.
  test('reset_mid_run_no_alert', () {
    final w = wired([inst(0, seconds: 60, alert: 'a.mp3')]);
    w.session.start();
    warpBy(secs(30));
    w.session.reset();
    expect(alerts.events, isEmpty);
  });

  // ── Sound resolution ───────────────────────────────────────────────────

  // An exact match in the listing wins — no fallback needed.
  test('sound_resolution_prefers_requested_file', () {
    expect(resolveAlertSound('b.mp3', ['a.mp3', 'b.mp3', 'c.mp3']), 'b.mp3');
  });

  // Listing order is filesystem order, not preference: fall back to the
  // alphabetically first file (String.compareTo).
  test('sound_resolution_falls_back_alphabetical_first', () {
    expect(
      resolveAlertSound('missing.mp3', ['zebra.mp3', 'alpha.mp3']),
      'alpha.mp3',
    );
  });

  // An empty directory resolves to null: silent, notify-only.
  test('sound_resolution_empty_dir_returns_null', () {
    expect(resolveAlertSound('anything.mp3', []), isNull);
  });

  // Not in the listing (even a case variant — Linux names are
  // case-sensitive) → alphabetical fallback, never the requested string.
  test('sound_resolution_requested_not_in_listing_falls_back', () {
    expect(resolveAlertSound('Ding.mp3', ['ding.mp3']), 'ding.mp3');
    expect(resolveAlertSound('x.mp3', ['gong.wav', 'horn.wav']), 'gong.wav');
  });

  // A single-file listing resolves to that file, matched or not.
  test('sound_resolution_single_file_listing', () {
    expect(resolveAlertSound('only.mp3', ['only.mp3']), 'only.mp3');
    expect(resolveAlertSound('other.mp3', ['only.mp3']), 'only.mp3');
  });

  // Pure: repeated calls agree and the input listing is untouched.
  test('sound_resolution_is_pure_and_deterministic', () {
    final listing = ['zebra.mp3', 'alpha.mp3', 'mid.mp3'];
    final before = List<String>.of(listing);
    final first = resolveAlertSound('nope.mp3', listing);
    final second = resolveAlertSound('nope.mp3', listing);
    expect(first, 'alpha.mp3');
    expect(second, first);
    expect(listing, before);
  });

  // ── Run log / terminal persistence ─────────────────────────────────────

  // Both terminal kinds land as `run.terminal` change-log entries.
  test('terminal_entries_written_to_change_log', () async {
    final p = processor([inst(0), inst(1)]);
    p.emit(
      InstanceEnded(
        ordinal: 0,
        defId: 'a',
        terminal: TerminalState.done,
        endedAt: t0.add(secs(60)),
      ),
    );
    p.emit(
      InstanceEnded(
        ordinal: 1,
        defId: 'b',
        terminal: TerminalState.skipped,
        endedAt: t0.add(secs(90)),
      ),
    );
    await p.flush();

    final entries = await store.events();
    expect(entries.map((e) => e.kind), ['run.terminal', 'run.terminal']);
    expect(entries[0].payloadJson, contains('"ordinal":0'));
    expect(entries[0].payloadJson, contains('"defId":"a"'));
    expect(entries[0].payloadJson, contains('"terminal":"done"'));
    expect(entries[1].payloadJson, contains('"ordinal":1'));
    expect(entries[1].payloadJson, contains('"terminal":"skipped"'));
    // seq stays the store's authoritative order.
    expect(entries.map((e) => e.seq), [1, 2]);
  });

  // The entry's timestamp is the instance's computed END moment, not the
  // (later) wall-clock at write time — even when settled very late.
  test('terminal_entry_timestamp_is_instance_end_time', () async {
    final w = wired([inst(0, seconds: 60)]);
    w.session.start();
    warpBy(const Duration(minutes: 5)); // settle long after the real end
    w.session.settle(clock.current);
    await w.processor.flush();

    final entry = (await store.events()).single;
    expect(entry.timestampMs, t0.add(secs(60)).millisecondsSinceEpoch);
    expect(entry.timestampMs, isNot(clock.current.millisecondsSinceEpoch));
  });

  // Settling repeatedly re-derives nothing: one entry per ended instance.
  test('terminal_entries_one_per_ended_instance', () async {
    final w = wired([inst(0), inst(1)]);
    w.session.start();
    warpBy(secs(90)); // past ord0's zero
    w.session.settle(clock.current);
    w.session.settle(clock.current); // same late instant: no duplicate
    w.session.settle(clock.current);
    warpBy(secs(60)); // past ord1's zero too
    w.session.settle(clock.current);
    w.session.settle(clock.current);
    await w.processor.flush();

    final entries = await store.events();
    expect(entries.length, 2);
    expect(entries.map((e) => e.timestampMs), [
      t0.add(secs(60)).millisecondsSinceEpoch,
      t0.add(secs(120)).millisecondsSinceEpoch,
    ]);
  });

  // A second flush with nothing queued appends nothing.
  test('flush_is_idempotent', () async {
    final p = processor([inst(0)]);
    p.emit(
      InstanceEnded(
        ordinal: 0,
        defId: 'a',
        terminal: TerminalState.done,
        endedAt: t0.add(secs(60)),
      ),
    );
    await p.flush();
    await p.flush();
    await p.flush();
    expect((await store.events()).length, 1);
  });

  // A mixed run logs its skips and its completions side by side.
  test('skipped_and_done_entries_both_logged', () async {
    final w = wired([
      inst(0, seconds: 60, alert: 'a.mp3'),
      inst(1, seconds: 60),
      inst(2, seconds: 60),
    ]);
    w.session.start();
    expect(w.session.skipNext(), isTrue); // ord0 ends skipped at t0
    warpBy(secs(61)); // ord1 runs its course
    w.session.settle(clock.current);
    await w.processor.flush();

    final entries = await store.events();
    expect(entries.length, 2);
    final payload0 = jsonDecode(entries[0].payloadJson) as Map<String, dynamic>;
    final payload1 = jsonDecode(entries[1].payloadJson) as Map<String, dynamic>;
    expect(payload0['ordinal'], 0);
    expect(payload0['terminal'], 'skipped');
    expect(payload1['ordinal'], 1);
    expect(payload1['terminal'], 'done');
    expect(entries[0].timestampMs, t0.millisecondsSinceEpoch); // skip = now
    expect(
      entries[1].timestampMs,
      t0.add(secs(60)).millisecondsSinceEpoch, // true end, not settle time
    );
  });

  // Alerts are decided at EMIT time — the store write can lag behind.
  test('alerts_fire_before_flush', () async {
    final p = processor([inst(0, alert: 'a.mp3')]);
    p.emit(
      InstanceEnded(
        ordinal: 0,
        defId: 'a',
        terminal: TerminalState.done,
        endedAt: t0.add(secs(60)),
      ),
    );
    expect(alerts.events.single.soundFile, 'a.mp3'); // already decided...
    expect(await store.events(), isEmpty); // ...while the log is still pending
    await p.flush();
    expect((await store.events()).length, 1);
  });

  // ── Integration ────────────────────────────────────────────────────────

  // Full run through a REAL TimerSession wired to the processor: auto →
  // manual hold → advance → auto cascade to fresh, with the complete sink,
  // alert, and run-log sequences asserted.
  test('warp_clock_full_run_event_sequence', () async {
    final w = wired(
      [
        inst(0, seconds: 60, name: 'one', alert: 'a.mp3'),
        inst(1, seconds: 60, autoFinish: false, name: 'two', alert: 'b.mp3'),
        inst(2, seconds: 60, name: 'three'), // no alert
        inst(3, seconds: 30, name: 'four', alert: 'zz.mp3'),
      ],
      listing: ['zz.mp3', 'a.mp3', 'b.mp3'],
      timerName: 'Full chain',
    );
    expect(w.session.start(), isTrue);

    warpBy(secs(90)); // ord0 done@+60; ord1 running (30s consumed)
    w.session.settle(clock.current);
    warpBy(secs(40)); // now +130: ord1 zeroed@+120, holding at zero
    w.session.settle(clock.current);
    expect(
      w.session.snapshot(clock.current).state,
      SessionState.awaitingAdvance,
    );
    expect(w.session.skipNext(), isTrue); // → ord2 running, full remaining
    w.session.settle(clock.current);
    warpBy(secs(200)); // now +330: ord2 done@+190, ord3 done@+220 → fresh
    w.session.settle(clock.current);
    expect(w.session.snapshot(clock.current).state, SessionState.notStarted);

    // The complete InstanceEnded sequence, in order, true end moments.
    expect(w.ended.events.map((e) => (e.ordinal, e.terminal.name)), [
      (0, 'done'),
      (1, 'done'),
      (2, 'done'),
      (3, 'done'),
    ]);
    expect(w.ended.events.map((e) => e.endedAt), [
      t0.add(secs(60)),
      t0.add(secs(120)),
      t0.add(secs(190)),
      t0.add(secs(220)),
    ]);

    // Exactly three alerts: ord2 had no sound; ord3 resolved 'zz.mp3'.
    expect(alerts.events.map((a) => (a.soundFile, a.ordinal)), [
      ('a.mp3', 0),
      ('b.mp3', 1),
      ('zz.mp3', 3),
    ]);

    await w.processor.flush();
    final entries = await store.events();
    expect(entries.map((e) => e.kind), List.filled(4, 'run.terminal'));
    final ordinals = [
      for (final e in entries)
        (jsonDecode(e.payloadJson) as Map<String, dynamic>)['ordinal'],
    ];
    expect(ordinals, [0, 1, 2, 3]);
    expect(entries.map((e) => e.timestampMs), [
      t0.add(secs(60)).millisecondsSinceEpoch,
      t0.add(secs(120)).millisecondsSinceEpoch,
      t0.add(secs(190)).millisecondsSinceEpoch,
      t0.add(secs(220)).millisecondsSinceEpoch,
    ]);
  });

  // Groundwork terminal states (cut/moved) are logged like any other end
  // and never alert — even for instances with a sound configured.
  test('processor_handles_cut_and_moved_without_alert', () async {
    final p = processor([inst(0, alert: 'a.mp3'), inst(1, alert: 'b.mp3')]);
    p.emit(
      InstanceEnded(
        ordinal: 0,
        defId: 'a',
        terminal: TerminalState.cut,
        endedAt: t0.add(secs(20)),
      ),
    );
    p.emit(
      InstanceEnded(
        ordinal: 1,
        defId: 'b',
        terminal: TerminalState.moved,
        endedAt: t0.add(secs(40)),
      ),
    );
    expect(alerts.events, isEmpty);
    await p.flush();

    final entries = await store.events();
    expect(entries.length, 2);
    final terminals = [
      for (final e in entries)
        (jsonDecode(e.payloadJson) as Map<String, dynamic>)['terminal'],
    ];
    expect(terminals, ['cut', 'moved']);
  });

  test('flush_failure_requeues_unprocessed_tail', () async {
    // A mid-drain store failure must not silently drop run-log entries: the
    // unprocessed tail goes back on the queue and lands on the next flush.
    final inner = DriftStore(
      PlannerDb(NativeDatabase.memory()),
      FixedClock(t0),
    );
    final failing = FailingStore(inner, failOnCall: 2); // second append dies
    final processor = RunEventProcessor(
      instances: [inst(0), inst(1), inst(2)],
      store: failing,
      timerName: 'chain',
      soundDirectoryListing: () => const [],
      alertSink: RecordingSink<PlayAlert>(),
    );
    for (var i = 0; i < 3; i++) {
      processor.emit(
        InstanceEnded(
          ordinal: i,
          defId: 'd$i',
          terminal: TerminalState.done,
          endedAt: t0.add(Duration(seconds: i)),
        ),
      );
    }

    await expectLater(processor.flush(), throwsA(isA<StateError>()));
    expect((await inner.events()).length, 1); // first entry landed

    await processor.flush(); // retry drains the requeued tail
    final events = await inner.events();
    expect(events.length, 3);
    expect(events.map((e) => e.timestampMs), [
      t0.millisecondsSinceEpoch,
      t0.add(const Duration(seconds: 1)).millisecondsSinceEpoch,
      t0.add(const Duration(seconds: 2)).millisecondsSinceEpoch,
    ]);
    await processor.flush(); // nothing left — idempotent
    expect((await inner.events()).length, 3);
    await inner.close();
  });

  test('fallback_uses_fresh_listing_at_fire_time', () async {
    // P5.1: the listing is read AT EVENT TIME, not construction time —
    // files added/removed after construction change the resolution.
    var listing = ['a.mp3'];
    final processor = RunEventProcessor(
      instances: [inst(0, alert: 'gone.mp3'), inst(1, alert: 'gone.mp3')],
      store: store,
      timerName: 't',
      soundDirectoryListing: () => listing,
      alertSink: alerts,
    );

    processor.emit(
      InstanceEnded(
        ordinal: 0,
        defId: 'd',
        terminal: TerminalState.done,
        endedAt: t0,
      ),
    );
    expect(alerts.events.single.soundFile, 'a.mp3'); // fallback at fire time

    listing = ['z-new.mp3']; // dir changed since construction
    processor.emit(
      InstanceEnded(
        ordinal: 1,
        defId: 'd',
        terminal: TerminalState.done,
        endedAt: t0,
      ),
    );
    expect(alerts.events.last.soundFile, 'z-new.mp3'); // fresh listing wins
  });
}

/// Delegating store whose Nth [appendEvent] fails exactly once — simulates a
/// disk error mid-flush; everything else forwards to the real inner store.
class FailingStore implements Store {
  FailingStore(this.inner, {required this.failOnCall});

  final Store inner;
  final int failOnCall;
  int _calls = 0;

  @override
  Future<void> appendEvent({
    required String kind,
    required int timestampMs,
    Map<String, Object?> payload = const {},
  }) {
    if (++_calls == failOnCall) throw StateError('simulated disk failure');
    return inner.appendEvent(
      kind: kind,
      timestampMs: timestampMs,
      payload: payload,
    );
  }

  @override
  Future<List<EventLogEntry>> events() => inner.events();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Mutable test clock: virtual time is free — assign [current] directly.
class FixedClock implements Clock {
  FixedClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

/// Collects every event of type [E] a sink receives, in order.
class RecordingSink<E> implements EventSink<E> {
  RecordingSink() : _forward = null;

  /// Wraps an existing [EventSink] by tee-ing into [events]: records every
  /// event and forwards it, so a real consumer can sit behind it.
  RecordingSink.of(EventSink<E> forward) : _forward = forward;

  final EventSink<E>? _forward;
  final List<E> events = [];

  @override
  void emit(E event) {
    events.add(event);
    _forward?.emit(event);
  }
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/editor_controller.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// AppController smoke tests (P2.1): boot defaults against a real in-memory
/// drift store, reload freshness, intent forwarding, snapshot mapping, the
/// settle+flush heartbeat, and the alert fan-out — all on a fixed clock with
/// recording adapters, no plugin code.
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late RecordingNotifier notifier;
  late RecordingPlayer player;
  late AppController controller;

  AppController makeController({List<String> Function()? soundListing}) =>
      AppController(
        store: store,
        clock: clock,
        notifier: notifier,
        player: player,
        soundsDir: '/sounds',
        soundListing: soundListing ?? () => const ['a.mp3', 'b.mp3'],
      );

  setUp(() {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);
    notifier = RecordingNotifier();
    player = RecordingPlayer();
    controller = makeController();
  });

  tearDown(() async {
    controller.dispose();
    await store.close();
  });

  IntervalDef def(
    String id, {
    int seconds = 30,
    bool autoFinish = true,
    String? name,
    String? alert,
  }) => IntervalDef(
    id: id,
    timerId: controller.timer.id,
    name: name,
    color: '#0055ff',
    durationSeconds: seconds,
    autoFinish: autoFinish,
    endAlertSoundFile: alert,
  );

  Future<void> saveDefs(List<IntervalDef> defs) => store.saveTree(
    controller.timer.id,
    IntervalTree([for (final d in defs) DefNode(d)]),
    eventKind: 'tree.edit',
  );

  // 1. Empty store: boot creates the v1 defaults.
  test('boot_creates_board_and_timer', () async {
    await controller.init();

    final boards = await store.allBoards();
    expect(boards.map((b) => b.name), ['My Board']);
    final timers = await store.timersInBoard(controller.board.id);
    expect(timers.map((t) => t.name), ['Interval timer']);
    expect(controller.snapshot.state, SessionState.notStarted);
  });

  // 2. Non-empty store: boot reuses what's there instead of duplicating.
  test('boot_reuses_existing_board_and_timer', () async {
    await controller.init();
    final second = makeController();
    addTearDown(second.dispose);
    await second.init();

    expect((await store.allBoards()).length, 1);
    expect(second.board.id, controller.board.id);
    expect((await store.timersInBoard(controller.board.id)).length, 1);
    expect(second.timer.id, controller.timer.id);
  });

  // 3. reload() picks up persisted definition edits and resets the run.
  test('reload_keeps_definitions_run_state_fresh', () async {
    await controller.init();
    await saveDefs([def('d1'), def('d2', seconds: 45, autoFinish: false)]);

    await controller.reload();

    expect(controller.instances.length, 2);
    expect(controller.snapshot.state, SessionState.notStarted);
  });

  // 4. Intent methods are thin forwards onto the session.
  test('intents_forward_to_session', () async {
    await controller.init();
    await saveDefs([def('d1')]);
    await controller.reload();

    expect(await controller.start(), isTrue);
    expect(controller.snapshot.state, SessionState.running);
    expect(controller.pause(), isTrue);
    expect(controller.snapshot.state, SessionState.paused);
    expect(controller.resume(), isTrue);
    expect(controller.snapshot.state, SessionState.running);
    await controller.reset();
    expect(controller.snapshot.state, SessionState.notStarted);
  });

  // 5. The snapshot maps the session's projection one-to-one.
  test('snapshot_maps_session_state', () async {
    await controller.init();
    await saveDefs([def('d1', seconds: 30), def('d2', seconds: 45)]);
    await controller.reload();

    expect(await controller.start(), isTrue);
    final s = controller.snapshot;
    expect(s.state, SessionState.running);
    expect(s.ordinal, 0);
    expect(s.currentLabel, isNull); // unnamed def
    expect(s.remaining, greaterThan(Duration.zero));
    expect(s.totalRemaining, const Duration(seconds: 75));
    expect(s.totalPlanned, const Duration(seconds: 75));
    expect(controller.isRunning, isTrue);
  });

  // 6. The heartbeat settles zero-crossings into run-log entries — once.
  test('tick_settles_and_flushes_run_log', () async {
    await controller.init();
    await saveDefs([def('d1', seconds: 1, autoFinish: false)]);
    await controller.reload();

    expect(await controller.start(), isTrue);
    clock.current = clock.current.add(const Duration(seconds: 2));
    await controller.tick();

    final afterFirst = await store.events();
    expect(
      afterFirst.where((e) => e.kind == 'run.terminal').length,
      1,
      reason: 'first tick must flush the done entry',
    );

    await controller.tick(); // nothing new crossed zero
    final afterSecond = await store.events();
    expect(afterSecond.where((e) => e.kind == 'run.terminal').length, 1);
  });

  // 7. A done instance with a configured sound fans out to notification AND
  //    playback with the resolved sound path.
  test('alert_fans_out_to_sound_and_notification', () async {
    final c = makeController(soundListing: () => ['x.mp3']);
    addTearDown(c.dispose);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'd1',
            timerId: c.timer.id,
            color: '#0055ff',
            durationSeconds: 1,
            autoFinish: true,
            endAlertSoundFile: 'x.mp3',
          ),
        ),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    expect(await c.start(), isTrue);
    clock.current = clock.current.add(const Duration(seconds: 2));
    await c.tick();

    // P5.1 copy: title = timer name; body = 'N. label'. Auto-finish alert
    // → no Continue action (the chain already moved on).
    expect(
      notifier.shows,
      [
        (
          title: 'Interval timer',
          body: '1. Interval',
          actionKey: null,
          actionLabel: null,
        ),
      ],
    );
    expect(player.played, ['/sounds/x.mp3']);
  });

  test('alert_fires_regardless_of_focus', () async {
    // No widget tree, no window state: the pipeline is focus-independent by
    // construction (D5 — the app process runs in the tray; alerts fire from
    // the heartbeat regardless of visibility).
    final c = makeController(soundListing: () => ['x.mp3']);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 1,
          autoFinish: true,
          endAlertSoundFile: 'x.mp3',
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    await c.start();
    clock.current = clock.current.add(const Duration(seconds: 2));
    await c.tick();

    expect(notifier.shows, hasLength(1));
    expect(player.played, ['/sounds/x.mp3']);
    c.dispose();
    await store.close();
  });

  test('manual_zero_fires_alert_and_holds', () async {
    final c = makeController(soundListing: () => ['x.mp3']);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 1,
          autoFinish: false, // manually complete: holds at zero
          endAlertSoundFile: 'x.mp3',
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    await c.start();
    clock.current = clock.current.add(const Duration(seconds: 2));
    await c.tick();

    // Alert fired at zero AND the session holds awaiting advance.
    expect(notifier.shows, hasLength(1));
    expect(player.played, ['/sounds/x.mp3']);
    expect(c.snapshot.state, SessionState.awaitingAdvance);
    expect(c.snapshot.remaining, Duration.zero);
    c.dispose();
    await store.close();
  });

  // AUTO-FINISH alert: the sound plays ONCE, hard-cut at 75% of the NEXT
  // instance's duration so consecutive alerts can never overlap.
  test('auto_alert_sound_cut_at_75_of_next_interval', () async {
    final c = makeController(soundListing: () => ['x.mp3']);
    addTearDown(c.dispose);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 60,
          autoFinish: true,
          endAlertSoundFile: 'x.mp3',
        )),
        DefNode(IntervalDef(
          id: 'd2',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 20,
          autoFinish: true,
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    await c.start();
    clock.current = clock.current.add(const Duration(seconds: 61));
    await c.tick();

    expect(player.played, ['/sounds/x.mp3']);
    expect(player.lastLoop, isFalse);
    expect(player.lastMaxDuration, const Duration(milliseconds: 20 * 750));
  });

  // Last instance of the run: no next interval → no cut.
  test('auto_alert_last_interval_uncapped', () async {
    final c = makeController(soundListing: () => ['x.mp3']);
    addTearDown(c.dispose);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 60,
          autoFinish: true,
          endAlertSoundFile: 'x.mp3',
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    await c.start();
    clock.current = clock.current.add(const Duration(seconds: 61));
    await c.tick();

    expect(player.played, ['/sounds/x.mp3']);
    expect(player.lastLoop, isFalse);
    expect(player.lastMaxDuration, isNull);
  });

  // MANUAL-FINISH alert: loops with a hard 10-minute cap (cut, not
  // "finish the last pass").
  test('manual_alert_loops_with_10_minute_cap', () async {
    final c = makeController(soundListing: () => ['x.mp3']);
    addTearDown(c.dispose);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 60,
          autoFinish: false,
          endAlertSoundFile: 'x.mp3',
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    await c.start();
    clock.current = clock.current.add(const Duration(seconds: 61));
    await c.tick();

    expect(player.played, ['/sounds/x.mp3']);
    expect(player.lastLoop, isTrue);
    expect(player.lastMaxDuration, const Duration(minutes: 10));
    expect(c.snapshot.state, SessionState.awaitingAdvance);
  });

  // Completing the held interval (tap-to-continue / notification Continue
  // / skip — all funnel through skipNext) cuts the loop immediately.
  test('advance_cuts_looping_alert', () async {
    final c = makeController(soundListing: () => ['x.mp3']);
    addTearDown(c.dispose);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 60,
          autoFinish: false,
          endAlertSoundFile: 'x.mp3',
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    await c.start();
    clock.current = clock.current.add(const Duration(seconds: 61));
    await c.tick();
    expect(player.stopCount, 0);

    expect(c.skipNext(), isTrue);
    expect(player.stopCount, 1);
  });

  // Reset while looping cuts the alert too (the run is abandoned).
  test('reset_cuts_looping_alert', () async {
    final c = makeController(soundListing: () => ['x.mp3']);
    addTearDown(c.dispose);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 60,
          autoFinish: false,
          endAlertSoundFile: 'x.mp3',
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    await c.start();
    clock.current = clock.current.add(const Duration(seconds: 61));
    await c.tick();
    expect(player.stopCount, 0);

    await c.reset();
    expect(player.stopCount, 1);
  });

  // The 'Continue' action button appears ONLY on a manually-complete
  // instance's alert (it holds at zero — advancing is meaningful); the
  // auto-finish chain has already moved on, so its alert stays a plain
  // body-click notification.
  test('continue_action_only_for_manually_complete', () async {
    final c = makeController(soundListing: () => ['x.mp3']);
    addTearDown(c.dispose);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 1,
          autoFinish: false, // manually complete: holds at zero
          endAlertSoundFile: 'x.mp3',
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    expect(await c.start(), isTrue);
    clock.current = clock.current.add(const Duration(seconds: 2));
    await c.tick();

    expect(notifier.shows, [
      (
        title: 'Interval timer',
        body: '1. Interval',
        actionKey: 'continue',
        actionLabel: 'Continue',
      ),
    ]);

    // The same alert from an auto-finish instance carries no action.
    notifier.shows.clear();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 1,
          autoFinish: true,
          endAlertSoundFile: 'x.mp3',
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    expect(await c.start(), isTrue);
    clock.current = clock.current.add(const Duration(seconds: 2));
    await c.tick();

    expect(notifier.shows, [
      (
        title: 'Interval timer',
        body: '1. Interval',
        actionKey: null,
        actionLabel: null,
      ),
    ]);
  });

  test('notify_only_when_no_sound_resolves', () async {
    // Empty sounds dir: the alert still notifies (D13) but plays nothing.
    final c = makeController(soundListing: () => const []);
    await c.init();
    await store.saveTree(
      c.timer.id,
      IntervalTree([
        DefNode(IntervalDef(
          id: 'd1',
          timerId: c.timer.id,
          color: '#0055ff',
          durationSeconds: 1,
          autoFinish: true,
          endAlertSoundFile: 'gone.mp3',
        )),
      ]),
      eventKind: 'tree.edit',
    );
    await c.reload();

    await c.start();
    clock.current = clock.current.add(const Duration(seconds: 2));
    await c.tick();

    expect(notifier.shows, hasLength(1));
    expect(player.played, isEmpty); // nothing resolved in an empty dir
    c.dispose();
    await store.close();
  });

  /// The timer ENTITY is re-fetched on reload — without it the board's
  /// dial color (and name) stayed stale until an app restart.
  test('reload_picks_up_timer_color_change', () async {
    await controller.init();
    await store.updateTimer(controller.timer.id, color: '#ff00b1');

    await controller.reload();

    expect(controller.timer.color, '#ff00b1');
  });

  // Tweaks #9: moving on in-app dismisses visible notifications (their
  // stale Continue goes with them); pause/resume leave them alone.
  test('advance_dismisses_notifications_pause_does_not', () async {
    await controller.init();
    await saveDefs([def('a'), def('b')]);
    await controller.reload();
    await controller.start();
    controller.pause();
    controller.resume();
    expect(notifier.closes, 0);
    expect(controller.skipNext(), isTrue);
    expect(notifier.closes, 1);
    expect(controller.jumpTo(0), isTrue);
    expect(notifier.closes, 2);
    await controller.reset();
    expect(notifier.closes, 3);
  });

  // Tweaks #7: adjustTime is ephemeral — promoting a held instance back
  // to running cuts the loop and drops its stale notification; a plain
  // nudge mid-run dismisses nothing.
  test('adjust_time_promotion_cuts_alerts_and_notifications', () async {
    await controller.init();
    await saveDefs([def('a', seconds: 30, autoFinish: false), def('b')]);
    await controller.reload();
    await controller.start();
    clock.current = clock.current.add(const Duration(seconds: 35));
    await controller.tick(); // manual instance holds at zero
    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    final closesBefore = notifier.closes;
    expect(await controller.adjustTime(20), isTrue);
    expect(controller.snapshot.state, SessionState.running);
    expect(controller.snapshot.remaining, const Duration(seconds: 20));
    expect(notifier.closes, closesBefore + 1);
    expect(await controller.adjustTime(5), isTrue); // plain nudge
    expect(notifier.closes, closesBefore + 1);
  });

  // Tweaks #5: silenceAlarm stops the sound but keeps the hold — the
  // notification stays (its Continue still completes).
  test('silence_alarm_keeps_the_hold', () async {
    await controller.init();
    await saveDefs([def('a', seconds: 30, autoFinish: false), def('b')]);
    await controller.reload();
    await controller.start();
    clock.current = clock.current.add(const Duration(seconds: 35));
    await controller.tick();
    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    final closesBefore = notifier.closes;
    controller.silenceAlarm();
    expect(controller.snapshot.state, SessionState.awaitingAdvance);
    expect(notifier.closes, closesBefore);
  });

  // Tweaks #7 bugfix (user report): a 5s interval given +10s must be
  // 5s again after reset — the adjustment is per-RUN, never per-
  // definition.
  test('reset_replays_planned_durations', () async {
    await controller.init();
    await saveDefs([def('a', seconds: 5), def('b')]);
    await controller.reload();
    await controller.start();
    expect(await controller.adjustTime(10), isTrue);
    expect(controller.snapshot.remaining, const Duration(seconds: 15));
    await controller.reset();
    await controller.start();
    expect(controller.snapshot.remaining, const Duration(seconds: 5));
  });

  // Tweaks #8 (the user's report): Done on a running timer must not
  // reset the run — the edit applies live, remaining re-derives as
  // new − elapsed.
  test('apply_tree_edit_keeps_the_run', () async {
    await controller.init();
    await saveDefs([def('a', seconds: 5), def('b', seconds: 5)]);
    await controller.reload();
    await controller.start();
    clock.current = clock.current.add(const Duration(seconds: 2));
    await controller.tick();
    // The edit grows interval a from 5s to 10s.
    await saveDefs([def('a', seconds: 10), def('b', seconds: 5)]);
    await controller.applyTreeEdit();
    expect(controller.snapshot.state, SessionState.running);
    expect(controller.snapshot.remaining, const Duration(seconds: 8)); // 10-2
    // The old path (reload) is what used to reset it.
    await controller.reload();
    expect(controller.snapshot.state, SessionState.notStarted);
  });

  test('apply_tree_edit_deleted_current_continues_at_next', () async {
    await controller.init();
    await saveDefs([def('a', seconds: 5), def('b', seconds: 7)]);
    await controller.reload();
    await controller.start();
    clock.current = clock.current.add(const Duration(seconds: 2));
    await controller.tick();
    // The edit deletes the RUNNING interval a.
    await saveDefs([def('b', seconds: 7)]);
    await controller.applyTreeEdit();
    expect(controller.snapshot.state, SessionState.running);
    expect(controller.snapshot.ordinal, 0);
    expect(controller.snapshot.remaining, const Duration(seconds: 7));
  });

  // ── P4.1: date-bound controllers + the lazy fork ───────────────────

  final dayDate = DateTime(2026, 3, 2); // YYYYMMDD 20260302

  /// Boots the default plan (two intervals), pins the day to it via a
  /// date rule, and returns the source (placeholder) plan id.
  Future<String> setupDayPlan() async {
    await controller.init();
    await saveDefs([def('d1'), def('d2', seconds: 45)]);
    await store.addRule(
      timerId: controller.timer.id,
      kind: DefaultRuleKind.date,
      value: 20260302,
    );
    return controller.timer.id;
  }

  /// A second controller bound to [dayDate] (disposed by tearDown).
  AppController makeDayController() {
    final day = makeController();
    addTearDown(day.dispose);
    return day;
  }

  // The placeholder invariant: opening a day (init + snapshot reads)
  // renders the rule-resolved plan and writes NOTHING — no day row, no
  // copy, no events.
  test('day_open_is_read_only_and_materializes_nothing', () async {
    final sourceId = await setupDayPlan();
    final eventsBefore = (await store.events()).length;
    final day = makeDayController();

    await day.init(dayDate: dayDate);

    expect(day.dayDate, dayDate);
    expect(day.timer.id, sourceId); // the placeholder, not a copy
    expect(day.snapshot.state, SessionState.notStarted); // a pure read
    expect(await store.dayPlanId(dayDate), isNull);
    expect(await store.resolveDayPlan(dayDate), sourceId);
    expect(
      (await store.timersInBoard(day.board.id)).where((t) => t.dayDate != null),
      isEmpty,
      reason: 'no day timer was created',
    );
    expect(
      (await store.events()).length,
      eventsBefore,
      reason: 'a read-only open appends no events',
    );
  });

  // The first-write trigger: a checkmark materializes the day's copy
  // exactly once, and BOTH the mark and its persistence land on the copy
  // — the placeholder never changes.
  test('first_mark_toggle_materializes_once_and_lands_on_the_copy', () async {
    final sourceId = await setupDayPlan();
    final day = makeDayController();
    await day.init(dayDate: dayDate);

    expect(await day.toggleMark(0), isTrue);

    final forkId = await store.dayPlanId(dayDate);
    expect(forkId, isNotNull);
    expect(forkId, isNot(sourceId));
    expect(day.timer.id, forkId, reason: 'the controller rebinds to the copy');

    final copy = await store.loadTree(forkId!);
    expect(copy.allNodes.whereType<DefNode>().first.def.completed, isTrue);
    final source = await store.loadTree(sourceId);
    expect(
      source.allNodes.whereType<DefNode>().first.def.completed,
      isFalse,
      reason: 'the placeholder must not receive the day\u2019s write',
    );

    // Exactly once: a second write reuses the same copy.
    await day.toggleMark(1);
    expect(await store.dayPlanId(dayDate), forkId);
    expect(
      (await store.timersInBoard(day.board.id)).where((t) => t.dayDate != null),
      hasLength(1),
    );
    expect(
      (await store.events()).where((e) => e.kind == 'day.materialize'),
      hasLength(1),
    );
  });

  // A run start is a first-write trigger too: the run executes over the
  // copy's fresh ids, and its persisted entries carry them.
  test('run_start_materializes_and_the_run_lands_on_the_copy', () async {
    final sourceId = await setupDayPlan();
    final day = makeDayController();
    await day.init(dayDate: dayDate);

    expect(await day.start(), isTrue);

    final forkId = await store.dayPlanId(dayDate);
    expect(forkId, isNotNull);
    expect(day.timer.id, forkId);

    clock.current = clock.current.add(const Duration(seconds: 46));
    await day.tick();

    final copyIds = (await store.loadTree(forkId!)).allIds.toSet();
    final runIds = {for (final i in day.instances) i.defId};
    expect(
      runIds.difference(copyIds),
      isEmpty,
      reason: 'the run executes over the copy\u2019s ids',
    );
    expect(
      runIds.intersection((await store.loadTree(sourceId)).allIds.toSet()),
      isEmpty,
    );
    expect(
      (await store.events()).where((e) => e.kind == 'run.terminal'),
      isNotEmpty,
      reason: 'the flushed run entry came from the live copy',
    );
    expect(
      (await store.events()).where((e) => e.kind == 'day.materialize'),
      hasLength(1),
    );
  });

  // The tree-save path: applyTreeEdit materializes first (idempotent —
  // the editor's commit already landed via timerForWrite, direct callers
  // fork here).
  test('apply_tree_edit_materializes_the_day', () async {
    final sourceId = await setupDayPlan();
    final day = makeDayController();
    await day.init(dayDate: dayDate);

    await day.applyTreeEdit();

    final forkId = await store.dayPlanId(dayDate);
    expect(forkId, isNotNull);
    expect(day.timer.id, forkId);
    expect(day.tree.allIds, isNotEmpty);
    expect((await store.loadTree(sourceId)).allIds, [
      'd1',
      'd2',
    ], reason: 'the placeholder is untouched');
    expect(
      (await store.events()).where((e) => e.kind == 'day.materialize'),
      hasLength(1),
    );
  });

  // The editor's commit resolves its target through the controller — on
  // a day board the edit materializes the day and lands on the copy;
  // the library plan never sees it.
  test('editor_commit_on_a_day_lands_on_the_copy', () async {
    final sourceId = await setupDayPlan();
    final day = makeDayController();
    await day.init(dayDate: dayDate);

    final editor = EditorController(
      store: store,
      timer: day.timer,
      initialTree: IntervalTree([
        DefNode(
          IntervalDef(
            id: 'fresh',
            timerId: day.timer.id,
            name: 'Added',
            color: '#0055ff',
            durationSeconds: 10,
            autoFinish: true,
          ),
        ),
      ]),
      resolveTimer: day.timerForWrite,
    );
    await editor.commit();

    final forkId = await store.dayPlanId(dayDate);
    expect(forkId, isNotNull);
    expect(forkId, isNot(sourceId));
    final copy = await store.loadTree(forkId!);
    expect(copy.allNodes.whereType<DefNode>().single.def.name, 'Added');
    expect(
      copy.allNodes.single.id,
      'fresh',
      reason: 'the re-target keeps every id (only ownership changes)',
    );
    expect((await store.loadTree(sourceId)).allIds, [
      'd1',
      'd2',
    ], reason: 'the edit must never reach the placeholder');
    expect(day.timer.id, forkId, reason: 'timerForWrite rebound the board');
  });

  // The reset clearing: a mark on the day's copy is cleared on that same
  // copy — the materialization happened at the first write and is not
  // repeated.
  test('reset_clearing_lands_on_the_copy', () async {
    await setupDayPlan();
    final day = makeDayController();
    await day.init(dayDate: dayDate);
    await day.toggleMark(0); // first write → materialized
    final forkId = await store.dayPlanId(dayDate);
    expect(forkId, isNotNull);

    await day.reset();

    final copy = await store.loadTree(forkId!);
    expect(
      copy.allNodes.whereType<DefNode>().every((n) => !n.def.completed),
      isTrue,
      reason: 'Reset cleared the marks on the day\u2019s own copy',
    );
    expect(
      (await store.events()).where((e) => e.kind == 'day.materialize'),
      hasLength(1),
      reason: 'reset never re-materializes',
    );
  });

  // The adjustment path materializes too (a first-write trigger); an
  // inert nudge on a not-started run still forks the day exactly once.
  test('adjust_time_materializes_the_day', () async {
    await setupDayPlan();
    final day = makeDayController();
    await day.init(dayDate: dayDate);

    await day.adjustTime(10);

    final forkId = await store.dayPlanId(dayDate);
    expect(forkId, isNotNull);
    expect(day.timer.id, forkId);
    expect(
      (await store.events()).where((e) => e.kind == 'day.materialize'),
      hasLength(1),
    );
  });
}

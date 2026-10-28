import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
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

    expect(controller.start(), isTrue);
    expect(controller.snapshot.state, SessionState.running);
    expect(controller.pause(), isTrue);
    expect(controller.snapshot.state, SessionState.paused);
    expect(controller.resume(), isTrue);
    expect(controller.snapshot.state, SessionState.running);
    controller.reset();
    expect(controller.snapshot.state, SessionState.notStarted);
  });

  // 5. The snapshot maps the session's projection one-to-one.
  test('snapshot_maps_session_state', () async {
    await controller.init();
    await saveDefs([def('d1', seconds: 30), def('d2', seconds: 45)]);
    await controller.reload();

    expect(controller.start(), isTrue);
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

    expect(controller.start(), isTrue);
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

    expect(c.start(), isTrue);
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

    c.start();
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

    c.start();
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

    expect(c.start(), isTrue);
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

    expect(c.start(), isTrue);
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

    c.start();
    clock.current = clock.current.add(const Duration(seconds: 2));
    await c.tick();

    expect(notifier.shows, hasLength(1));
    expect(player.played, isEmpty); // nothing resolved in an empty dir
    c.dispose();
    await store.close();
  });
}

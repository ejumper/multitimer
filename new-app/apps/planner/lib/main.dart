import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'package:drift/native.dart';
import 'package:planner_engine/planner_engine.dart';

import 'adapters/kde_notifier.dart';
import 'adapters/mp3_player.dart';
import 'adapters/planner_store.dart';
import 'adapters/system_clock.dart';
import 'alert_handler.dart';
import 'app_controller.dart';
import 'board_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Unattended smoke check (P2 report): fire one real KDE notification and
  // exit — no window, no tray.
  final smoke = Platform.environment['PLANNER_SMOKE'];
  if (smoke == '1') {
    await _smoke();
    return;
  }
  if (smoke == 'alert') {
    await _smokeAlert();
    return;
  }

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Planner',
      size: Size(1024, 800),
      minimumSize: Size(640, 480),
      center: true,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
  // Close is handled by [_CloseBehavior] (hybrid — see below); the raw
  // close event must be swallowed so it can decide hide-vs-quit.
  await windowManager.setPreventClose(true);

  await _initTray();

  // System adapters + app state seam (P2.1): on-disk store under the XDG
  // data dir, wall-clock time, KDE notifications, GStreamer sound.
  await ensurePlannerDirs();
  final store = await openPlannerStore();
  // The notifier is built before the controller (the construction order
  // predates the action), so the 'continue' action routes through a
  // nullable holder assigned right after the controller exists.
  AppController? controller;
  final notifier = KdeNotifier(
    onNotificationClick: _showWindow,
    onAction: (key) {
      if (key == 'continue') {
        // Tweaks #10: only advance while the run is actually held — a
        // click that races an in-app advance must not skip ANOTHER one.
        final c = controller;
        if (c != null && continueAdvances(c.snapshot.state)) c.skipNext();
      }
    },
  );
  await notifier.init();
  final appController = AppController(
    store: store,
    clock: SystemClock(),
    notifier: notifier,
    player: Mp3Player(),
    soundsDir: plannerSoundsDir(),
    soundListing: listSoundFiles,
  );
  controller = appController;
  await appController.init();

  // Hybrid close (acceptance): a LIVE run hides to tray so its alerts keep
  // firing (D5 — no daemon; the process must outlive the window); idle
  // closes for real.
  windowManager.addListener(_CloseBehavior(appController));

  runApp(PlannerApp(controller: appController));
}

/// Unattended smoke path (`PLANNER_SMOKE=1`): opens the real store and fires
/// one real KDE notification, then exits. Prints `SMOKE_OK` on success,
/// `SMOKE_FAIL: <error>` on failure.
Future<void> _smoke() async {
  try {
    await ensurePlannerDirs();
    final store = await openPlannerStore();
    final notifier = KdeNotifier(onNotificationClick: () {});
    await notifier.init();
    await notifier.show(title: 'Planner', body: 'Smoke test notification');
    // ignore: avoid_print
    print('SMOKE_OK');
    await store.close();
    exit(0);
  } catch (e) {
    // ignore: avoid_print
    print('SMOKE_FAIL: $e');
    exit(1);
  }
}

/// The real exit. windowManager.destroy() tears the GTK window down and
/// takes the process with it via a teardown SIGSEGV — KDE then shows a
/// crash notification for a perfectly normal close. State is durable
/// (the store commits per statement), so a clean process exit is the
/// honest end.
void quitPlanner() {
  exit(0);
}

/// Whether the notification's Continue action may advance (tweaks #10):
/// only while the run is held at zero. If the user already advanced
/// in-app, a late click is a no-op instead of skipping another interval.
bool continueAdvances(SessionState state) =>
    state == SessionState.awaitingAdvance;

/// Whether a close request should hide to tray (true) or quit (false):
/// a live run is worth protecting — closing must not kill its alerts.
bool closeHidesToTray(SessionState state) => state != SessionState.notStarted;

/// The window-close policy (hybrid close, acceptance): hide to tray while
/// a timer run is active, quit when idle. Alt+F4 / the task-manager close
/// ride the same path as the window's close button.
class _CloseBehavior extends WindowListener {
  _CloseBehavior(this.controller);

  final AppController controller;

  @override
  void onWindowClose() {
    if (closeHidesToTray(controller.snapshot.state)) {
      unawaited(windowManager.hide());
    } else {
      quitPlanner();
    }
  }
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planner',
      debugShowCheckedModeBanner: false,
      theme: buildPlannerTheme(),
      home: BoardScreen(controller),
    );
  }
}

void _showWindow() {
  windowManager.show();
  windowManager.focus();
}

/// Tray setup via system_tray (per-platform plugin; Linux path uses
/// ayatana-appindicator/StatusNotifier — the tray_manager 0.8/nativeapi path
/// silently failed to register on this desktop, see P0.2 report).
///
/// On KDE the panel opens the context menu on any icon click and click events
/// are not delivered to the app — so "tray click → show window" goes through
/// the menu's "Show Planner" item, which is the KDE-idiomatic behavior. The
/// Quit item is the real exit.
Future<void> _initTray() async {
  final SystemTray systemTray = SystemTray();

  await systemTray.initSystemTray(
    title: 'Planner',
    iconPath: 'assets/tray/planner_tray.png',
  );

  final Menu menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(label: 'Show Planner', onClicked: (_) => _showWindow()),
    MenuSeparator(),
    MenuItemLabel(
      label: 'Quit',
      // ignore: discarded_futures
      onClicked: (_) async => quitPlanner(),
    ),
  ]);

  await systemTray.setContextMenu(menu);

  // Not delivered on Linux (the panel keeps the clicks); wired for other
  // platforms / future use.
  systemTray.registerSystemTrayEventHandler((eventName) {
    if (eventName == kSystemTrayEventClick) {
      _showWindow();
    }
  });
}

/// Full-pipeline alert smoke (`PLANNER_SMOKE=alert`): drives a real
/// 1-second session to zero through the engine (TimerSession →
/// RunEventProcessor → AlertHandler) into the REAL notifier and player.
/// The in-memory store keeps the user's change log clean. With an empty
/// sounds dir this also exercises the notify-only fallback live (D13).
/// Prints `SMOKE_OK` after the alert side effects had their chance to fire.
Future<void> _smokeAlert() async {
  try {
    await ensurePlannerDirs();
    final clock = SystemClock();
    final notifier = KdeNotifier(onNotificationClick: () {});
    await notifier.init();
    final player = Mp3Player();
    final store = DriftStore(PlannerDb(NativeDatabase.memory()), clock);

    const instance = IntervalInstance(
      ordinal: 0,
      defId: 'smoke',
      name: 'Smoke',
      color: '#0055ff',
      durationSeconds: 1,
      autoFinish: true,
      endAlertSoundFile: 'smoke.mp3',
    );
    final processor = RunEventProcessor(
      instances: const [instance],
      store: store,
      timerName: 'Planner smoke',
      soundDirectoryListing: listSoundFiles,
      alertSink: AlertHandler(
        player: player,
        notifier: notifier,
        soundsDir: plannerSoundsDir(),
      ),
    );
    final session = TimerSession(
      const [instance],
      clock: clock,
      sink: processor,
    );

    session.start();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    session.settle(clock.now());
    await processor.flush();
    await Future<void>.delayed(const Duration(milliseconds: 600));

    // ignore: avoid_print
    print('SMOKE_OK');
    await store.close();
    exit(0);
  } catch (e) {
    // ignore: avoid_print
    print('SMOKE_FAIL: $e');
    exit(1);
  }
}

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'mock_board.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  // Close button hides to tray instead of quitting (D5: no daemon; the app
  // must keep running while closed so alarms can fire).
  await windowManager.setPreventClose(true);

  await _initTray();

  runApp(const PlannerApp());
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planner',
      debugShowCheckedModeBanner: false,
      theme: buildPlannerTheme(),
      home: const MockBoardPage(),
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
      onClicked: (_) {
        // Real exit — destroys the window and ends the process.
        windowManager.destroy();
      },
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

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'ports.dart';

/// KDE (freedesktop) notifications via flutter_local_notifications' pure-Dart
/// DBus implementation.
///
/// A notification-body click fires the `default` action, whose handler runs
/// [onNotificationClick] — wired in `main.dart` to show/focus the window, so
/// this adapter stays decoupled from window management. Notification ids
/// increment per [show] call.
class KdeNotifier implements Notifier {
  KdeNotifier({required this.onNotificationClick});

  /// Invoked when the user clicks a notification (default action).
  final VoidCallback onNotificationClick;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  int _nextId = 0;
  bool _initialized = false;

  /// Initializes the plugin; must be awaited before the first [show].
  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      linux: LinuxInitializationSettings(defaultActionName: 'default'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) => onNotificationClick(),
    );
    _initialized = true;
  }

  @override
  Future<void> show({required String title, required String body}) async {
    // Body clicks fire the `default` action (see init) → onNotificationClick.
    // No explicit action buttons (out of v1 scope).
    await _plugin.show(
      _nextId++,
      title,
      body,
      const NotificationDetails(linux: LinuxNotificationDetails()),
    );
  }
}

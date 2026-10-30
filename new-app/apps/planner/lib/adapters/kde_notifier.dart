import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'ports.dart';

/// KDE (freedesktop) notifications via flutter_local_notifications' pure-Dart
/// DBus implementation.
///
/// A notification-body click fires the `default` action, whose handler runs
/// [onNotificationClick] — wired in `main.dart` to show/focus the window.
/// An explicit action-button click carries its key in `actionId` and routes
/// to [onAction] instead (body click keeps its focus behavior — only the
/// action key diverts). Notification ids increment per [show] call.
class KdeNotifier implements Notifier {
  KdeNotifier({required this.onNotificationClick, this.onAction});

  /// Invoked when the user clicks the notification body (default action).
  final VoidCallback onNotificationClick;

  /// Invoked with the action key when the user taps a notification ACTION
  /// BUTTON (e.g. 'continue'); null for body clicks.
  final void Function(String actionKey)? onAction;

  /// Tweak #9: the plugin's Linux cancelAll issues the freedesktop
  /// CloseNotification call per id — KDE drops the banners immediately.
  @override
  Future<void> closeVisible() => _plugin.cancelAll();

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
      onDidReceiveNotificationResponse: (response) {
        // Body/default click → actionId == null → focus; the 'continue'
        // action button → advance the held-at-zero instance.
        if (response.actionId == 'continue') {
          onAction?.call('continue');
        } else {
          onNotificationClick();
        }
      },
    );
    _initialized = true;
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? actionKey,
    String? actionLabel,
  }) async {
    // Body clicks fire the `default` action (see init) → onNotificationClick;
    // a non-null actionKey adds one labeled action button routed to onAction.
    // expiresNever = remain on screen until the user closes it (acceptance
    // "Notification Expiration").
    final details = actionKey == null
        ? const NotificationDetails(
            linux: LinuxNotificationDetails(
              timeout: LinuxNotificationTimeout.expiresNever(),
            ),
          )
        : NotificationDetails(
            linux: LinuxNotificationDetails(
              timeout: LinuxNotificationTimeout.expiresNever(),
              actions: [
                LinuxNotificationAction(
                  key: actionKey,
                  label: actionLabel ?? actionKey,
                ),
              ],
            ),
          );
    await _plugin.show(_nextId++, title, body, details);
  }
}

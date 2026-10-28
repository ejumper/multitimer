import 'dart:async';

import 'package:planner_engine/planner_engine.dart';

import 'adapters/ports.dart';

/// Fans one decided end alert ([PlayAlert]) out to sound + notification.
///
/// A notification ALWAYS accompanies an end alert — when the alert has no
/// resolved sound file it is notify-only. The sound is fire-and-forget
/// (`.catchError`): a broken player or notification daemon must never throw
/// back into engine logic ([EventSink] contract).
class AlertHandler implements EventSink<PlayAlert> {
  AlertHandler({
    required this.player,
    required this.notifier,
    required this.soundsDir,
  });

  final SoundPlayer player;
  final Notifier notifier;
  final String soundsDir;

  @override
  void emit(PlayAlert alert) {
    unawaited(
      notifier
          .show(
            title: alert.intervalName ?? 'Interval ${alert.ordinal + 1}',
            body: alert.timerName,
          )
          .catchError((Object _) {}),
    );
    final soundFile = alert.soundFile;
    if (soundFile != null) {
      unawaited(player.play('$soundsDir/$soundFile').catchError((Object _) {}));
    }
  }
}

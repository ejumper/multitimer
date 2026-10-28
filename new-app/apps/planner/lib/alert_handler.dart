import 'dart:async';

import 'package:planner_engine/planner_engine.dart';

import 'adapters/ports.dart';

/// Fans one decided end alert ([PlayAlert]) out to sound + notification.
///
/// A notification ALWAYS accompanies an end alert — when the alert has no
/// resolved sound file it is notify-only. The sound is fire-and-forget
/// (`.catchError`): a broken player or notification daemon must never throw
/// back into engine logic ([EventSink] contract).
///
/// Sound policy:
///  - AUTO-FINISH instance: play ONCE, hard-cut at 75% of the NEXT instance's
///    duration (null next = no cut) — consecutive alerts can never overlap;
///  - MANUALLY complete instance (holds at zero): LOOP the sound until the
///    interval is completed, with a hard 10-minute cap (if the user let it
///    go that long they are not hearing it).
///    [stopAlerts] cuts both immediately — called when the held interval
///    gets completed (tap-to-continue / Continue / skip / jump) or the run
///    resets.
class AlertHandler implements EventSink<PlayAlert> {
  AlertHandler({
    required this.player,
    required this.notifier,
    required this.soundsDir,
  });

  /// Hard cap on a looping (manually complete) alert sound.
  static const Duration loopCap = Duration(minutes: 10);

  /// Fraction of the NEXT instance's duration a one-shot alert may occupy.
  static const int cutPercentOfNext = 75;

  final SoundPlayer player;
  final Notifier notifier;
  final String soundsDir;

  @override
  void emit(PlayAlert alert) {
    // "Continue" is only meaningful for a MANUALLY COMPLETE instance
    // holding at zero — an auto-finish chain has already moved on, so its
    // alert stays a plain body-click notification.
    final manualHold = !alert.autoFinish;
    unawaited(
      notifier
          .show(
            // P5.1 copy: title = the timer; body = the interval's number+label.
            title: alert.timerName,
            body: '${alert.ordinal + 1}. ${alert.intervalName ?? 'Interval'}',
            actionKey: manualHold ? 'continue' : null,
            actionLabel: manualHold ? 'Continue' : null,
          )
          .catchError((Object _) {}),
    );
    final soundFile = alert.soundFile;
    if (soundFile != null) {
      final nextSeconds = alert.nextInstanceDurationSeconds;
      unawaited(
        player
            .play(
              '$soundsDir/$soundFile',
              loop: manualHold,
              maxDuration: manualHold
                  ? loopCap
                  : (nextSeconds != null
                        ? Duration(
                            milliseconds: nextSeconds * cutPercentOfNext * 10,
                          )
                        : null),
            )
            .catchError((Object _) {}),
      );
    }
  }

  /// Cuts any alert sound immediately (see the class doc).
  void stopAlerts() {
    unawaited(player.stop().catchError((Object _) {}));
  }
}

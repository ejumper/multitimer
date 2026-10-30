import 'package:planner/adapters/ports.dart';
import 'package:planner_engine/planner_engine.dart';

/// Shared test fakes: a mutable clock and recording adapters. No plugin code
/// anywhere — the real KdeNotifier/Mp3Player are constructed only in
/// `main.dart`.

/// Mutable test clock: virtual time is free — assign [current] directly.
class FixedClock implements Clock {
  FixedClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}

/// Captures every [Notifier.show] call, in order — including the optional
/// action-button pair (null = plain body-click notification).
class RecordingNotifier implements Notifier {
  final List<({String title, String body, String? actionKey, String? actionLabel})>
  shows = [];

  int closes = 0;

  @override
  Future<void> closeVisible() async {
    closes += 1;
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    String? actionKey,
    String? actionLabel,
  }) async {
    shows.add((
      title: title,
      body: body,
      actionKey: actionKey,
      actionLabel: actionLabel,
    ));
  }
}

/// Captures every [SoundPlayer] call: [played] in order, the options of
/// the LAST play, and the [stop] count.
class RecordingPlayer implements SoundPlayer {
  final List<String> played = [];
  bool? lastLoop;
  Duration? lastMaxDuration;
  int stopCount = 0;

  @override
  Future<void> play(
    String filePath, {
    bool loop = false,
    Duration? maxDuration,
  }) async {
    played.add(filePath);
    lastLoop = loop;
    lastMaxDuration = maxDuration;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

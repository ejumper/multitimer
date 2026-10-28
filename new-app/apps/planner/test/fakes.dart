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

/// Captures every [Notifier.show] call, in order.
class RecordingNotifier implements Notifier {
  final List<({String title, String body})> shows = [];

  @override
  Future<void> show({required String title, required String body}) async {
    shows.add((title: title, body: body));
  }
}

/// Captures every [SoundPlayer.play] call, in order.
class RecordingPlayer implements SoundPlayer {
  final List<String> played = [];

  @override
  Future<void> play(String filePath) async {
    played.add(filePath);
  }
}

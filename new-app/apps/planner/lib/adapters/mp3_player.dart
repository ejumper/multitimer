import 'package:audioplayers/audioplayers.dart';

import 'ports.dart';

/// Alert-sound playback via audioplayers (GStreamer on Linux).
///
/// Plays each file to completion. OVERLAPPING calls QUEUE: one in-flight
/// [AudioPlayer], a FIFO queue behind it, drained on `onPlayerComplete` — a
/// slow sound delays the next one but never cuts it off. A failed file is
/// dropped without wedging the queue.
class Mp3Player implements SoundPlayer {
  Mp3Player() {
    _player.onPlayerComplete.listen((_) => _startNextIfIdle());
  }

  final AudioPlayer _player = AudioPlayer();
  final List<String> _queue = <String>[];
  bool _inFlight = false;

  @override
  Future<void> play(String filePath) async {
    if (_inFlight) {
      _queue.add(filePath);
      return;
    }
    await _playOne(filePath);
  }

  Future<void> _playOne(String filePath) async {
    _inFlight = true;
    try {
      await _player.play(UrlSource(filePath));
    } catch (_) {
      // A failed file must not wedge the queue — move on to the next.
      _startNextIfIdle();
    }
  }

  void _startNextIfIdle() {
    if (_queue.isEmpty) {
      _inFlight = false;
      return;
    }
    _playOne(_queue.removeAt(0));
  }

  /// Stops the current sound and drops the queue (for completeness).
  Future<void> stop() async {
    _queue.clear();
    _inFlight = false;
    await _player.stop();
  }

  Future<void> dispose() => _player.dispose();
}

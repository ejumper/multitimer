import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'ports.dart';

/// Absolute sound file path → a `file://` URI.
///
/// audioplayers' Linux backend is a native plugin that hands the string
/// straight to GStreamer's `playbin` "uri" property, which REQUIRES a URI
/// scheme — a bare path is rejected as "Invalid URI" before the file is
/// ever touched (DeviceFileSource passes the same raw path, so the source
/// type cannot fix it; the URI must be built here).
String soundFileUri(String filePath) => Uri.file(filePath).toString();

/// Alert-sound playback via audioplayers (GStreamer on Linux).
///
/// Interrupt semantics: a new [play] stops whatever is playing and takes
/// over (the alert rules cut off overlapping sounds by design — a FIFO
/// queue behind a 10-minute loop would be absurd). [loop] repeats via
/// GStreamer's native loop mode until [stop] or the [maxDuration] HARD cut
/// (mid-pass is fine — a capped sound does not get a last pass).
class Mp3Player implements SoundPlayer {
  Mp3Player() {
    // Nothing to do on completion any more (interrupt + cap semantics),
    // but the listener must exist WITH an error handler: the platform
    // event stream also reports source errors, and with no listener those
    // surface as unhandled async exceptions (the "Unhandled Exception"
    // spam when a sound is missing).
    _player.onPlayerComplete.listen((_) {}, onError: (Object _) {});
  }

  final AudioPlayer _player = AudioPlayer();
  Timer? _cap;

  @override
  Future<void> play(
    String filePath, {
    bool loop = false,
    Duration? maxDuration,
  }) async {
    await stop(); // new alerts interrupt whatever is playing
    try {
      await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.play(UrlSource(soundFileUri(filePath)));
      if (maxDuration != null) {
        _cap = Timer(maxDuration, () => unawaited(stop()));
      }
    } catch (_) {
      // A broken or missing file must never throw back into the alert path.
    }
  }

  @override
  Future<void> stop() async {
    _cap?.cancel();
    _cap = null;
    try {
      await _player.stop();
    } catch (_) {
      // Best-effort cut.
    }
  }

  Future<void> dispose() => _player.dispose();
}

/// App-side ports for the two system adapters that no test can (or should)
/// instantiate: desktop notifications and sound playback. The real
/// implementations ([KdeNotifier], [Mp3Player]) are constructed only in
/// `main.dart`; tests inject recording fakes — no plugin code in tests.
library;

/// Desktop notification delivery.
abstract interface class Notifier {
  /// Shows a notification with the given [title] and [body].
  Future<void> show({required String title, required String body});
}

/// Alert-sound playback.
abstract interface class SoundPlayer {
  /// Plays the mp3 at the absolute [filePath] to completion.
  Future<void> play(String filePath);
}

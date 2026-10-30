/// App-side ports for the two system adapters that no test can (or should)
/// instantiate: desktop notifications and sound playback. The real
/// implementations ([KdeNotifier], [Mp3Player]) are constructed only in
/// `main.dart`; tests inject recording fakes — no plugin code in tests.
library;

/// Desktop notification delivery.
abstract interface class Notifier {
  /// Shows a notification with the given [title] and [body].
  ///
  /// When [actionKey] is non-null, the notification carries an action
  /// button labeled [actionLabel] (falling back to [actionKey]); tapping it
  /// routes back to the adapter's action handler instead of focusing the
  /// window. Both null = plain body-click-only notification.
  Future<void> show({
    required String title,
    required String body,
    String? actionKey,
    String? actionLabel,
  });

  /// Dismisses every visible notification from this app — called when the
  /// run moves on in-app (tweaks #9): a held/complete notification must
  /// not linger with a stale Continue action.
  Future<void> closeVisible();
}

/// Alert-sound playback.
abstract interface class SoundPlayer {
  /// Plays the mp3 at the absolute [filePath].
  ///
  /// [loop] repeats the sound until [stop] or the [maxDuration] cap — the
  /// cap is a HARD cut (mid-pass is fine). [maxDuration] also truncates a
  /// one-shot play. A new [play] INTERRUPTS whatever is playing.
  Future<void> play(
    String filePath, {
    bool loop = false,
    Duration? maxDuration,
  });

  /// Cuts the current sound immediately (also cancels a pending cap).
  Future<void> stop();
}

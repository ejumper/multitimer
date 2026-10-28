/// Event-consumption layer (P1.4, v1 thin slice): consumes the session's
/// [InstanceEnded] stream to (a) append terminal-state run-log entries to
/// the change log and (b) decide end alerts.
///
/// v1 scope is deliberately thin: alert on `done`, log every terminal state.
/// Pre-warnings, repeat alerts, and vibration are OUT of scope — the
/// [EventSink] boundary keeps them addable without touching the engine.
///
/// Wiring: the app builds `TimerSession(instances, clock: clock, sink:
/// processor)` with a [RunEventProcessor] as the sink and calls [flush] on
/// its heartbeat. Alerts fire at [RunEventProcessor.emit] time, NOT at flush
/// time — sound should never wait on the database.
library;

import 'events.dart';
import 'flatten.dart';
import 'storage/store.dart';

/// Decided at instance zero: play an end alert.
class PlayAlert {
  const PlayAlert({
    required this.soundFile,
    required this.timerName,
    required this.intervalName,
    required this.ordinal,
  });

  /// RESOLVED file name; null = no sound but still notify.
  final String? soundFile;

  /// The timer's display name, snapshotted by [RunEventProcessor].
  final String timerName;

  /// The instance's name snapshot (null = unnamed).
  final String? intervalName;

  /// Ordinal of the instance that reached zero.
  final int ordinal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayAlert &&
          other.soundFile == soundFile &&
          other.timerName == timerName &&
          other.intervalName == intervalName &&
          other.ordinal == ordinal;

  @override
  int get hashCode => Object.hash(soundFile, timerName, intervalName, ordinal);

  @override
  String toString() =>
      'PlayAlert(sound=$soundFile, timer=$timerName, '
      'interval=${intervalName ?? '<unnamed>'}, #$ordinal)';
}

/// Pure sound resolution: exact match in [availableFiles] wins (Linux file
/// names are case-sensitive); otherwise the first file alphabetically
/// ([String.compareTo]); an empty listing resolves to null (silent,
/// notify-only). Does not mutate [availableFiles].
String? resolveAlertSound(String requested, List<String> availableFiles) {
  if (availableFiles.contains(requested)) return requested;
  if (availableFiles.isEmpty) return null;
  final sorted = [...availableFiles]..sort();
  return sorted.first;
}

/// Consumes the session's [InstanceEnded] stream: (a) appends
/// `run.terminal` entries to the [Store], (b) decides end alerts.
///
/// An instance that reaches zero ([TerminalState.done]) alerts iff its
/// [IntervalInstance.endAlertSoundFile] is configured — BOTH finish methods
/// (auto-finish and manually-complete) alert at zero. Skipped/cut/moved
/// instances never alert (skipped ≠ alerted — documented decision); their
/// run-log entry is still queued.
class RunEventProcessor implements EventSink<InstanceEnded> {
  RunEventProcessor({
    required this.instances,
    required this.store,
    required this.timerName,
    required this.soundDirectoryListing,
    required this.alertSink,
  });

  /// The flattened list the session plays; [IntervalInstance.ordinal] == index.
  final List<IntervalInstance> instances;

  /// Persistence target for the `run.terminal` entries.
  final Store store;

  /// The timer's display name, attached to every [PlayAlert].
  final String timerName;

  /// Injected file names of the alert-sound directory (no dart:io here).
  final List<String> soundDirectoryListing;

  /// Where decided alerts go (the app side: sound, notification, UI).
  final EventSink<PlayAlert> alertSink;

  final List<InstanceEnded> _pending = [];

  @override
  void emit(InstanceEnded event) {
    // ALWAYS queued for the run log, whatever the terminal state.
    _pending.add(event);
    if (event.terminal != TerminalState.done) return; // skipped ≠ alerted
    final instance = instances[event.ordinal];
    final requested = instance.endAlertSoundFile;
    if (requested == null) return; // no configured sound → no alert
    alertSink.emit(
      PlayAlert(
        soundFile: resolveAlertSound(requested, soundDirectoryListing),
        timerName: timerName,
        intervalName: instance.name,
        ordinal: event.ordinal,
      ),
    );
  }

  /// Drains the queued run-log entries in order via [Store.appendEvent] and
  /// empties the queue; a second flush with nothing queued appends nothing.
  /// Alerts fire at [emit] time, NOT here. If an append fails mid-drain the
  /// unprocessed tail goes back on the queue (rethrown to the caller) — the
  /// append-only log never silently drops entries.
  Future<void> flush() async {
    final batch = List<InstanceEnded>.of(_pending);
    _pending.clear();
    for (var i = 0; i < batch.length; i++) {
      try {
        await store.appendEvent(
          kind: 'run.terminal',
          timestampMs: batch[i].endedAt.millisecondsSinceEpoch,
          payload: {
            'ordinal': batch[i].ordinal,
            'defId': batch[i].defId,
            'terminal': batch[i].terminal.name,
          },
        );
      } catch (_) {
        _pending.insertAll(0, batch.sublist(i));
        rethrow;
      }
    }
  }
}

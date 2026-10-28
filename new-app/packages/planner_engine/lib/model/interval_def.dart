/// The interval as *authored* in the editor: an [IntervalDef].
///
/// Terminology is load-bearing (CONVENTIONS §1): this is a definition, not a
/// playback occurrence. `autoFinish` is the finish method — `true` =
/// auto-finish, `false` = manually complete (holds at zero). NEVER call this
/// "autocomplete" (that is MultiTimer's whole-timer auto-reset, which we do
/// not have).
library;

/// Groundwork enum (v1: stored, defaulted, never surfaced).
enum CompletionState { completed, notCompleted }

/// Groundwork enum (v1: always [TriggerMethod.order]; `date` exists as
/// schema/groundwork only).
enum TriggerMethod { order, date }

/// One authored interval.
class IntervalDef {
  const IntervalDef({
    required this.id,
    required this.timerId,
    this.name,
    required this.color,
    required this.durationSeconds,
    required this.autoFinish,
    this.endAlertSoundFile,
    this.completionDefault = CompletionState.notCompleted,
    this.trigger = TriggerMethod.order,
  }) : assert(
         durationSeconds > 0,
         'durationSeconds must be > 0 (v1 has no no-duration intervals, D12)',
       );

  /// UUIDv4 string.
  final String id;
  final String timerId;

  /// Optional label (MultiTimer-style); null = unnamed.
  final String? name;

  /// Hex color string from the v1 preset swatches (D11).
  final String color;

  /// Authored duration in seconds; always > 0 in v1 (D12: setter always on).
  final int durationSeconds;

  /// Finish method: true = auto-finish, false = manually complete.
  final bool autoFinish;

  /// Optional end-alert sound file path/identifier (user-supplied mp3; null =
  /// no end alert). Start alerts are not in v1.
  final String? endAlertSoundFile;

  /// Groundwork: completion state stored per interval. v1 always defaults to
  /// [CompletionState.notCompleted] and is never surfaced.
  final CompletionState completionDefault;

  /// Groundwork: trigger method. v1 is always [TriggerMethod.order].
  final TriggerMethod trigger;

  IntervalDef copyWith({
    String? name,
    String? color,
    int? durationSeconds,
    bool? autoFinish,
    String? endAlertSoundFile,
  }) => IntervalDef(
    id: id,
    timerId: timerId,
    name: name ?? this.name,
    color: color ?? this.color,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    autoFinish: autoFinish ?? this.autoFinish,
    endAlertSoundFile: endAlertSoundFile ?? this.endAlertSoundFile,
    completionDefault: completionDefault,
    trigger: trigger,
  );

  @override
  String toString() =>
      'IntervalDef($id, ${name ?? '<unnamed>'}, ${color}S, '
      '${durationSeconds}s, autoFinish=$autoFinish, '
      'alert=${endAlertSoundFile ?? 'none'})';
}

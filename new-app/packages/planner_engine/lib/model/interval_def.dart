/// The interval as *authored* in the editor: an [IntervalDef].
///
/// Terminology is load-bearing (v2 CONVENTIONS §1): this is a definition, not
/// a playback occurrence. `autoFinish` is the finish method — `true` =
/// auto-finish, `false` = manually complete (holds at zero). NEVER call this
/// "autocomplete" (that is MultiTimer's whole-timer auto-reset, which we do
/// not have).
///
/// v2 (P1.1) makes this the four-property interval (OVERVIEW §1):
/// - **completion** — [completed], the *work* mark, orthogonal to how the
///   instance ends (`done`/`cut`/`skipped` are execution).
/// - **duration** — nullable: `null` = **Open** (no duration; acts like a
///   zero-duration manual interval — instant, alert, hold).
/// - **finish method** — [autoFinish]; requires a duration (an Open interval
///   is always manually complete).
/// - **trigger** — [triggerTimeSeconds]: `null` = **order** (starts when the
///   previous interval finishes); non-null = **date** (a wall firing at that
///   local time-of-day, seconds since midnight).
library;

/// One authored interval.
class IntervalDef {
  const IntervalDef({
    required this.id,
    required this.timerId,
    this.name,
    required this.color,
    this.durationSeconds,
    required this.autoFinish,
    this.endAlertSoundFile,
    this.completed = false,
    this.triggerTimeSeconds,
  }) : assert(
         durationSeconds == null || durationSeconds > 0,
         'durationSeconds must be null (Open) or > 0',
       ),
       assert(
         !autoFinish || durationSeconds != null,
         'auto-finish requires a duration (Open intervals hold manually)',
       ),
       assert(
         triggerTimeSeconds == null ||
             (triggerTimeSeconds >= 0 && triggerTimeSeconds < 24 * 60 * 60),
         'triggerTimeSeconds is seconds since midnight, 0..86399',
       );

  /// UUIDv4 string.
  final String id;
  final String timerId;

  /// Optional label (MultiTimer-style); null = unnamed.
  final String? name;

  /// Hex color string from the v1 preset swatches (D11).
  final String color;

  /// Authored duration in seconds; null = **Open** (no duration).
  final int? durationSeconds;

  /// Finish method: true = auto-finish, false = manually complete. Only
  /// meaningful with a duration (asserted above).
  final bool autoFinish;

  /// Optional end-alert sound file path/identifier (user-supplied mp3; null =
  /// no end alert). Start alerts are not in the app.
  final String? endAlertSoundFile;

  /// The **completion mark**: did the work happen. Cleared by Reset and by
  /// copies/forks (a copy is new work); persisted so task lists keep their
  /// checks.
  final bool completed;

  /// The **trigger method** by presence: null = order-triggered; non-null =
  /// date-triggered (a wall) firing at this local time-of-day (seconds since
  /// midnight). v2 rule: walls live in the top-level chain only — never
  /// inside a repeating group (enforced at authoring, P1.5).
  final int? triggerTimeSeconds;

  /// True for date-triggered (wall) intervals.
  bool get isDated => triggerTimeSeconds != null;

  /// True for Open intervals (no duration).
  bool get isOpen => durationSeconds == null;

  static const _unset = Object();

  IntervalDef copyWith({
    String? name,
    String? color,
    Object? durationSeconds = _unset,
    bool? autoFinish,
    Object? endAlertSoundFile = _unset,
    bool? completed,
    Object? triggerTimeSeconds = _unset,
  }) => IntervalDef(
    id: id,
    timerId: timerId,
    name: name ?? this.name,
    color: color ?? this.color,
    durationSeconds: identical(durationSeconds, _unset)
        ? this.durationSeconds
        : durationSeconds as int?,
    autoFinish: autoFinish ?? this.autoFinish,
    endAlertSoundFile: identical(endAlertSoundFile, _unset)
        ? this.endAlertSoundFile
        : endAlertSoundFile as String?,
    completed: completed ?? this.completed,
    triggerTimeSeconds: identical(triggerTimeSeconds, _unset)
        ? this.triggerTimeSeconds
        : triggerTimeSeconds as int?,
  );

  @override
  String toString() =>
      'IntervalDef($id, ${name ?? '<unnamed>'}, '
      '${durationSeconds == null ? 'open' : '${durationSeconds}s'}, '
      'autoFinish=$autoFinish, completed=$completed, '
      'at=${triggerTimeSeconds ?? 'order'})';
}

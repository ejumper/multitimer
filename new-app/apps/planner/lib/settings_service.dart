/// P5.2 — the app's settings seam: typed getters/setters with sane
/// defaults over the engine store's opaque key/value table
/// (`Store.getSetting` / `Store.setSetting`), plus change notification
/// ([SettingsService] is a [ChangeNotifier] — the Settings page listens
/// to its own service).
///
/// Reads are CACHED: [load] pulls every key once and the getters answer
/// synchronously from then on; every setter writes through to the store
/// and then notifies. Open-time consumers (the interval editor's CREATE
/// seed, the calendar's initial view) construct a transient service and
/// [load] it — a one-shot fresh read that can never see a stale cache.
///
/// The engine stores opaque TEXT: booleans as '1'/'0', the calendar view
/// as its wire name — parsing and defaults live here, never in the
/// engine (CONVENTIONS §2's layer rule).
library;

import 'package:flutter/foundation.dart';
import 'package:planner_engine/planner_engine.dart';

/// The `settings` table keys.
const String kSettingEventOverridesDefault = 'event.overridesDefault';
const String kSettingHomePlanId = 'home.planId';
const String kSettingIntervalAutoFinish = 'interval.autoFinish';
const String kSettingIntervalDuration = 'interval.duration';
const String kSettingIntervalTime = 'interval.time';
const String kSettingCalendarDefaultView = 'calendar.defaultView';

/// Wire values of [kSettingCalendarDefaultView] (stored as given — the
/// same name-mapping style the default rules' wire values use).
const String kCalendarViewWeek = 'week';
const String kCalendarViewMonth = 'month';

/// Typed accessors over the `settings` table. Defaults mirror the
/// outline (P5.2): Overwrite OFF · Home = the current day's timer ·
/// Auto-finish OFF / Duration ON / Time OFF (the P1.5 hard-coded
/// defaults) · calendar = week.
class SettingsService extends ChangeNotifier {
  SettingsService(this.store);

  final Store store;

  /// Whether new events (dated intervals) start with the capture's
  /// Overwrite Default Timer toggle ON (default OFF).
  bool eventOverridesDefault = false;

  /// Home = this plan's board, or null for the current day's timer.
  /// Stored as the empty string when cleared (the table has no delete;
  /// [load] maps empty back to null).
  String? homePlanId;

  /// The Interval Options defaults for NEW intervals (an EDIT seeds from
  /// the def): Auto-finish OFF, Duration ON, Time OFF.
  bool intervalAutoFinish = false;
  bool intervalDuration = true;
  bool intervalTime = false;

  /// The calendar's initial view: [kCalendarViewWeek] (default) or
  /// [kCalendarViewMonth].
  String calendarDefaultView = kCalendarViewWeek;

  bool _loaded = false;
  bool _disposed = false;

  /// Whether [load] has completed (getters answer the defaults until it
  /// does — sane answers even for a reader racing the load).
  bool get loaded => _loaded;

  /// Reads every key fresh from the store (typed, defaults for unset
  /// keys) and notifies. Repeatable — a later call re-reads.
  Future<void> load() async {
    eventOverridesDefault = await _readBool(
      kSettingEventOverridesDefault,
      false,
    );
    homePlanId = await _readHomePlan();
    intervalAutoFinish = await _readBool(kSettingIntervalAutoFinish, false);
    intervalDuration = await _readBool(kSettingIntervalDuration, true);
    intervalTime = await _readBool(kSettingIntervalTime, false);
    calendarDefaultView = await _readCalendarView();
    _loaded = true;
    _notify();
  }

  Future<bool> _readBool(String key, bool fallback) async =>
      switch (await store.getSetting(key)) {
        '1' => true,
        '0' => false,
        _ => fallback,
      };

  Future<String?> _readHomePlan() async {
    final raw = await store.getSetting(kSettingHomePlanId);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<String> _readCalendarView() async {
    final raw = await store.getSetting(kSettingCalendarDefaultView);
    return raw == kCalendarViewMonth ? kCalendarViewMonth : kCalendarViewWeek;
  }

  // ── setters: write through to the store, then notify ───────────────────

  Future<void> setEventOverridesDefault(bool value) async {
    eventOverridesDefault = value;
    await store.setSetting(kSettingEventOverridesDefault, value ? '1' : '0');
    _notify();
  }

  /// null = Home is the current day's timer (written as the empty
  /// string; [load] reads it back as null).
  Future<void> setHomePlanId(String? planId) async {
    homePlanId = planId;
    await store.setSetting(kSettingHomePlanId, planId ?? '');
    _notify();
  }

  Future<void> setIntervalAutoFinish(bool value) async {
    intervalAutoFinish = value;
    await store.setSetting(kSettingIntervalAutoFinish, value ? '1' : '0');
    _notify();
  }

  Future<void> setIntervalDuration(bool value) async {
    intervalDuration = value;
    await store.setSetting(kSettingIntervalDuration, value ? '1' : '0');
    _notify();
  }

  Future<void> setIntervalTime(bool value) async {
    intervalTime = value;
    await store.setSetting(kSettingIntervalTime, value ? '1' : '0');
    _notify();
  }

  /// [view] is [kCalendarViewWeek] or [kCalendarViewMonth]; anything
  /// else lands on week.
  Future<void> setCalendarDefaultView(String view) async {
    calendarDefaultView = view == kCalendarViewMonth
        ? kCalendarViewMonth
        : kCalendarViewWeek;
    await store.setSetting(kSettingCalendarDefaultView, calendarDefaultView);
    _notify();
  }

  void _notify() {
    // A setter's store write may outlive the page that started it — a
    // service disposed by its popped Settings page must not notify.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

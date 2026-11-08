import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planner_engine/planner_engine.dart';

import 'app_controller.dart';
import 'library_screen.dart';
import 'theme.dart';

/// DEFAULTS (v2 P3.4 — the outline's template rules): the plan board's
/// menu behind `btn-defaults`. Three flows, all writing [DefaultRule]s
/// through the store:
///
/// - **Make the default timer** → confirmation popup (the outline) → the
///   plan's global default rule.
/// - **Default for a day of the week…** → 7 weekday names + a "repeats
///   weekly" switch. Repeat on = a repeating `weekday` rule (1–7, Monday
///   = 1); repeat off = the picked day as a ONE-OFF — the rule claims
///   exactly that date (the upcoming occurrence from the injected clock),
///   stored as its YYYYMMDD value (P3.4: same day every week, off = that
///   one date).
/// - **Default for a day of the month…** → a 1–31 picker + a "repeats
///   monthly" switch, same repeat semantics (off = the upcoming
///   occurrence of that day-of-month).
///
/// Re-adding an identical rule is idempotent at the store, so the flows
/// need no dedup of their own. The SAME menu lists the plan's active
/// rules with a remove affordance (× per row) and reloads after every
/// add/remove — it stays open under its pickers/confirms.
///
/// Lives on [BoardBar.plan] only (board root and Library get no menu in
/// this chunk).
Future<void> showDefaultsMenu(BuildContext context, AppController controller) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent, // effect only behind the menu
      builder: (_) => _DefaultsMenu(controller),
    );

class _DefaultsMenu extends StatefulWidget {
  const _DefaultsMenu(this.controller);

  final AppController controller;

  @override
  State<_DefaultsMenu> createState() => _DefaultsMenuState();
}

class _DefaultsMenuState extends State<_DefaultsMenu> {
  AppController get controller => widget.controller;
  Store get _store => controller.store;

  List<DefaultRule> _rules = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final rules = await _store.rulesFor(controller.timer.id);
    if (!mounted) return;
    setState(() => _rules = rules);
  }

  // ── the three flows ────────────────────────────────────────────────────

  /// Flow 1 — the outline's "make the timer the default timer (with
  /// confirmation pop up)".
  Future<void> _makeDefault() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Make the default timer?',
      message: 'Days with no other rule are given this plan.',
      confirmLabel: 'Make default',
      confirmColor: AppColors.lightBlue,
    );
    if (!confirmed || !mounted) return;
    await _store.addRule(
      timerId: controller.timer.id,
      kind: DefaultRuleKind.globalDefault,
    );
    if (mounted) await _reload();
  }

  /// Flow 2 — pick a weekday under the "repeats weekly" switch.
  Future<void> _pickWeekday() async {
    final picked = await showDialog<({int day, bool repeat})>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => const _WeekdayPicker(),
    );
    if (picked == null || !mounted) return;
    await _store.addRule(
      timerId: controller.timer.id,
      kind: DefaultRuleKind.weekday,
      value: _weekRuleValue(picked.day, picked.repeat),
      repeat: picked.repeat,
    );
    if (mounted) await _reload();
  }

  /// Flow 3 — pick a day of the month under the "repeats monthly" switch.
  Future<void> _pickMonthday() async {
    final picked = await showDialog<({int day, bool repeat})>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => const _MonthdayPicker(),
    );
    if (picked == null || !mounted) return;
    await _store.addRule(
      timerId: controller.timer.id,
      kind: DefaultRuleKind.monthday,
      value: _monthRuleValue(picked.day, picked.repeat),
      repeat: picked.repeat,
    );
    if (mounted) await _reload();
  }

  /// The remove affordance per listed rule.
  Future<void> _remove(DefaultRule rule) async {
    await _store.removeRule(rule.id);
    if (mounted) await _reload();
  }

  // ── rule values ────────────────────────────────────────────────────────

  /// Repeating = the weekday itself (1–7); one-off = the claimed DATE —
  /// the upcoming occurrence of that weekday, on or after today (the
  /// injected clock's local day, CONVENTIONS §7).
  int _weekRuleValue(int weekday, bool repeat) {
    if (repeat) return weekday;
    final now = controller.clock.now();
    final delta = (weekday - now.weekday) % 7;
    return _yyyymmdd(DateTime.utc(now.year, now.month, now.day + delta));
  }

  /// Repeating = the day of month (1–31); one-off = the claimed DATE —
  /// the upcoming occurrence of that day-of-month (skipping months that
  /// don't have one: Feb 31 normalizes away).
  int _monthRuleValue(int dayOfMonth, bool repeat) {
    if (repeat) return dayOfMonth;
    final now = controller.clock.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    for (var k = 0; k < 24; k++) {
      final candidate = DateTime.utc(now.year, now.month + k, dayOfMonth);
      if (candidate.day != dayOfMonth) continue; // month lacks that day
      if (candidate.isBefore(today)) continue;
      return _yyyymmdd(candidate);
    }
    return dayOfMonth; // unreachable: every 1–31 recurs within 24 months
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('defaults-menu'),
      backgroundColor: Colors.black, // opaque menu panel
      shape: AppDecorations.menuShape,
      title: const Text('Defaults'),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              key: const Key('defaults-make-default'),
              onPressed: () => unawaited(_makeDefault()),
              child: const Text('Make the default timer'),
            ),
            TextButton(
              key: const Key('defaults-weekday'),
              onPressed: () => unawaited(_pickWeekday()),
              child: const Text('Default for a day of the week…'),
            ),
            TextButton(
              key: const Key('defaults-monthday'),
              onPressed: () => unawaited(_pickMonthday()),
              child: const Text('Default for a day of the month…'),
            ),
            const Divider(),
            if (_rules.isEmpty)
              Text(
                'No rules yet',
                key: const Key('defaults-empty'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 13,
                  color: AppColors.dimmed,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final rule in _rules) _ruleRow(rule)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ruleRow(DefaultRule rule) {
    return Row(
      key: Key('defaults-rule-${rule.id}'),
      children: [
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            describeDefaultRule(rule),
            key: Key('defaults-rule-text-${rule.id}'),
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13,
              color: AppColors.text,
            ),
          ),
        ),
        IconButton(
          key: Key('defaults-remove-${rule.id}'),
          icon: const Icon(Icons.close, size: 16, color: AppColors.dimmed),
          onPressed: () => unawaited(_remove(rule)),
        ),
      ],
    );
  }
}

/// The weekday picker (flow 2): the 7 weekday names in ISO order
/// (Monday = 1) + the outline's "same day every week" switch. Tapping a
/// name adds the rule — the dialog pops the pick; the menu writes it.
class _WeekdayPicker extends StatefulWidget {
  const _WeekdayPicker();

  @override
  State<_WeekdayPicker> createState() => _WeekdayPickerState();
}

class _WeekdayPickerState extends State<_WeekdayPicker> {
  bool _repeats = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('weekday-picker'),
      backgroundColor: Colors.black, // opaque menu panel
      shape: AppDecorations.menuShape,
      title: const Text('Default for a day of the week'),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (var weekday = 1; weekday <= 7; weekday++)
                  TextButton(
                    key: Key('weekday-$weekday'),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop((day: weekday, repeat: _repeats)),
                    child: Text(weekdayNames[weekday - 1]),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Repeats weekly',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                Switch(
                  key: const Key('switch-repeats-weekly'),
                  value: _repeats,
                  onChanged: (v) => setState(() => _repeats = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The day-of-month picker (flow 3): 1–31 + the outline's "same day every
/// month" switch, same add-on-tap shape as the weekday picker.
class _MonthdayPicker extends StatefulWidget {
  const _MonthdayPicker();

  @override
  State<_MonthdayPicker> createState() => _MonthdayPickerState();
}

class _MonthdayPickerState extends State<_MonthdayPicker> {
  bool _repeats = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('monthday-picker'),
      backgroundColor: Colors.black, // opaque menu panel
      shape: AppDecorations.menuShape,
      title: const Text('Default for a day of the month'),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (var day = 1; day <= 31; day++)
                  TextButton(
                    key: Key('monthday-$day'),
                    onPressed: () =>
                        Navigator.of(context).pop((day: day, repeat: _repeats)),
                    child: Text('$day'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Repeats monthly',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                Switch(
                  key: const Key('switch-repeats-monthly'),
                  value: _repeats,
                  onChanged: (v) => setState(() => _repeats = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekday names in ISO order (index 0 = Monday, matching the engine's
/// Monday = 1 rule values).
const List<String> weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// The menu row's text for a stored rule (English, ISO dates per
/// CONVENTIONS §7). One-off weekday/monthday rules carry their date, so
/// they read as plain days.
String describeDefaultRule(DefaultRule rule) {
  switch (rule.kind) {
    case DefaultRuleKind.globalDefault:
      return 'Default for all days';
    case DefaultRuleKind.date:
      return 'On ${_isoDay(rule.value)}';
    case DefaultRuleKind.weekday:
      if (!rule.repeat) return 'On ${_isoDay(rule.value)}';
      return 'Every ${weekdayNames[((rule.value ?? 1) - 1).clamp(0, 6)]}';
    case DefaultRuleKind.monthday:
      if (!rule.repeat) return 'On ${_isoDay(rule.value)}';
      return 'Day ${rule.value} of every month';
  }
}

/// YYYYMMDD → `YYYY-MM-DD` (ISO); a malformed value renders as-is.
String _isoDay(int? value) {
  if (value == null || value < 10000101) return '$value';
  final year = value ~/ 10000;
  final month = (value ~/ 100) % 100;
  final day = value % 100;
  String pad(int n) => n.toString().padLeft(2, '0');
  return '$year-${pad(month)}-${pad(day)}';
}

int _yyyymmdd(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

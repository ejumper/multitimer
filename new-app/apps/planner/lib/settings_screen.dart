import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planner_engine/planner_engine.dart';

import 'app_controller.dart';
import 'bottom_bar.dart';
import 'day_navigation.dart';
import 'settings_service.dart';
import 'theme.dart';

/// The Settings page (v2 P5.2, the outline's Settings section): every
/// setting the outline names, each pinned to its consumer —
///
/// * **New events override default timer by default** (Switch, OFF by
///   default) → seeds the capture's Overwrite Default Timer toggle;
/// * **Home**: "Current day's timer" (default) or "A specific plan" with
///   a plan picker → the [homeDayDate]/[openHome] seam (a specific plan
///   HOME opens that plan's board);
/// * **Interval Options defaults**: Auto-finish / Duration / Time
///   switches → the interval editor's CREATE seed (an EDIT still seeds
///   from the def);
/// * **Calendar default view**: week (default) / month → the calendar's
///   initial view;
/// * **Bottom Bar**: its one entry — a read-only line echoing the Home
///   definition above (the outline literally has only this).
///
/// Values live in the store's `settings` table through
/// [SettingsService] (loaded at open; every setter writes through and
/// notifies, so the page's switches track their own persisted state).
/// The plan picker lists the LIBRARY's plans by name (day forks never
/// appear — the Library rule).
///
/// Own bar (P3.1's page-contextual bars): **home** only (the outline).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen(this.controller, {super.key});

  /// The board's controller — the store seam the settings read/write
  /// through and Home opens its boards from.
  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppController get controller => widget.controller;

  late final SettingsService _settings = SettingsService(controller.store);

  /// The Library's plans (day forks excluded), keyed by id — the Home
  /// picker's options and the echo line's name lookup.
  Map<String, IntervalTimer> _plans = const {};

  /// First load finished — the one loading frame (the Library's rule),
  /// so the switches never render unseeded values.
  bool _ready = false;

  /// The plan picker's double-tap guard (the async dialog seam).
  bool _pickingPlan = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final plans = await controller.store.timersInBoard(controller.board.id);
    await _settings.load();
    if (!mounted) return;
    setState(() {
      _plans = {
        for (final plan in plans)
          if (plan.dayDate == null) plan.id: plan,
      };
      _ready = true;
    });
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('settings-page'),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Same reading width as the board and editor (520).
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: const [
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: !_ready
                      ? const SizedBox.shrink() // one frame of loading
                      : ListenableBuilder(
                          listenable: _settings,
                          builder: (context, _) => _content(),
                        ),
                ),
                const SizedBox(height: 12),
                _bar(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The settings bar: home only (P5.2 rule 6 — the outline's bar).
  Widget _bar(BuildContext context) {
    return BottomBar(
      key: const Key('settings-bar'),
      buttons: [
        BarButton(
          buttonKey: const Key('bar-home'),
          icon: Icons.home,
          // P4.3 → P5.2: Home = the Home definition above (today's day
          // board, or the configured specific plan's board).
          onPressed: () => unawaited(openHome(context, controller)),
        ),
      ],
    );
  }

  /// The Home plan when one is configured — null for the current-day
  /// home. A configured-but-deleted plan resolves to null here too (the
  /// row then offers the picker; [homePlanId] falls back to the day
  /// resolution exactly the same way).
  IntervalTimer? get _homePlan {
    final id = _settings.homePlanId;
    if (id == null) return null;
    return _plans[id];
  }

  Widget _content() {
    final plan = _homePlan;
    final specific = _settings.homePlanId != null;
    return SingleChildScrollView(
      key: const Key('settings-list'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader('NEW EVENTS'),
          _switchCard(
            switchKey: const Key('set-new-event-override'),
            title: 'New events override default timer by default',
            subtitle: 'New events start with Overwrite Default Timer on',
            value: _settings.eventOverridesDefault,
            onChanged: (value) =>
                unawaited(_settings.setEventOverridesDefault(value)),
          ),
          _sectionHeader('HOME'),
          _optionRow(
            rowKey: const Key('set-home-current-day'),
            title: 'Current day\u2019s timer',
            subtitle: 'Home opens the current day\u2019s timer',
            selected: !specific,
            onTap: () => unawaited(_settings.setHomePlanId(null)),
          ),
          const SizedBox(height: 6),
          _optionRow(
            rowKey: const Key('set-home-specific-plan'),
            title: 'A specific plan',
            subtitle: 'Home opens that plan\u2019s board',
            selected: specific,
            // Picking (again) opens the plan dialog; with no valid plan
            // chosen yet a cancel simply leaves Current day selected.
            onTap: () => unawaited(_pickPlan()),
          ),
          if (specific) ...[const SizedBox(height: 6), _planRow(plan)],
          _sectionHeader('INTERVAL OPTIONS DEFAULTS'),
          _switchCard(
            switchKey: const Key('set-default-autofinish'),
            title: 'Auto-finish',
            subtitle: 'Default for new intervals',
            value: _settings.intervalAutoFinish,
            // Auto-finish requires a duration (the engine contract): the
            // default is grayed out while the Duration default is OFF.
            onChanged: _settings.intervalDuration
                ? (value) => unawaited(_settings.setIntervalAutoFinish(value))
                : null,
          ),
          const SizedBox(height: 6),
          _switchCard(
            switchKey: const Key('set-default-duration'),
            title: 'Duration',
            subtitle: 'Default for new intervals',
            value: _settings.intervalDuration,
            onChanged: (value) => unawaited(_setDurationDefault(value)),
          ),
          const SizedBox(height: 6),
          _switchCard(
            switchKey: const Key('set-default-time'),
            title: 'Time',
            subtitle: 'Default for new intervals',
            value: _settings.intervalTime,
            onChanged: (value) => unawaited(_settings.setIntervalTime(value)),
          ),
          _sectionHeader('CALENDAR'),
          _optionRow(
            rowKey: const Key('set-cal-week'),
            title: 'Week',
            subtitle: 'Opens to the current week',
            selected: _settings.calendarDefaultView == kCalendarViewWeek,
            onTap: () =>
                unawaited(_settings.setCalendarDefaultView(kCalendarViewWeek)),
          ),
          const SizedBox(height: 6),
          _optionRow(
            rowKey: const Key('set-cal-month'),
            title: 'Month',
            subtitle: 'Opens to the current month',
            selected: _settings.calendarDefaultView == kCalendarViewMonth,
            onTap: () =>
                unawaited(_settings.setCalendarDefaultView(kCalendarViewMonth)),
          ),
          _sectionHeader('APPEARANCE'),
          _switchCard(
            switchKey: const Key('set-solid-background'),
            title: 'Solid background',
            subtitle: 'Paint #161616 behind the windows instead of transparency',
            value: _settings.solidBackground,
            onChanged: (value) =>
                unawaited(_settings.setSolidBackground(value)),
          ),
          _sectionHeader('BOTTOM BAR'),
          _homeEchoRow(plan),
        ],
      ),
    );
  }

  /// Section label — the Library's FOLDERS marker style.
  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 12,
          letterSpacing: 1.5,
          color: AppColors.dimmed,
        ),
      ),
    );
  }

  /// A titled toggle card (the editor's card vocabulary): title +
  /// caption left, the Switch right. [switchKey] lives on the Switch.
  Widget _switchCard({
    required Key switchKey,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: onChanged == null
                        ? AppColors.dimmed
                        : AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12,
                    color: AppColors.dimmed,
                  ),
                ),
              ],
            ),
          ),
          Switch(key: switchKey, value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// A two-way choice row (Home, Calendar view): radio glyph + title +
  /// caption, the whole card tappable.
  Widget _optionRow({
    required Key rowKey,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: rowKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.lightBlue : AppColors.dimmed,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.text : AppColors.dimmed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      color: AppColors.dimmed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The chosen plan's row (only while Home = a specific plan): the
  /// plan's name, or the missing-plan hint when it was deleted — tapping
  /// reopens the picker.
  Widget _planRow(IntervalTimer? plan) {
    return GestureDetector(
      key: const Key('set-home-plan'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_pickPlan()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plan',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan?.name ?? 'That plan no longer exists — pick another',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      color: plan == null ? AppColors.danger : AppColors.dimmed,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.dimmed),
          ],
        ),
      ),
    );
  }

  /// The Bottom Bar section's single entry (the outline): a read-only
  /// line echoing the Home definition above.
  Widget _homeEchoRow(IntervalTimer? plan) {
    return Container(
      key: const Key('set-bottom-bar-home'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'home',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plan != null
                      ? 'Opens ${plan.name}'
                      : 'Opens the current day\u2019s timer',
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12,
                    color: AppColors.dimmed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── actions ────────────────────────────────────────────────────────────

  /// The Home plan picker (P5.2): a small dialog listing the Library's
  /// plans BY NAME (alphabetical — a picker's boring order); picking
  /// persists the Home setting, cancelling changes nothing.
  Future<void> _pickPlan() async {
    if (_pickingPlan) return;
    _pickingPlan = true;
    final plans = _plans.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final picked = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent, // effect only behind the menu
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black, // opaque menu panel
        shape: AppDecorations.menuShape,
        title: const Text('Choose a plan'),
        content: SizedBox(
          width: 260,
          child: plans.isEmpty
              ? const Text(
                  'No plans in the Library yet.',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    color: AppColors.dimmed,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final plan in plans)
                      TextButton(
                        key: Key('home-plan-${plan.id}'),
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(plan.id),
                        child: Text(plan.name),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            key: const Key('dialog-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    _pickingPlan = false;
    if (picked == null || !mounted) return;
    await _settings.setHomePlanId(picked);
  }

  /// The Duration default's change: the engine's contract is
  /// auto-finish-requires-a-duration, so turning Duration OFF also
  /// lands Auto-finish OFF (the two switches can never hold the invalid
  /// combination).
  Future<void> _setDurationDefault(bool on) async {
    await _settings.setIntervalDuration(on);
    if (!on) await _settings.setIntervalAutoFinish(false);
  }
}

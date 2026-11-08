import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planner_engine/planner_engine.dart';

import 'app_controller.dart';
import 'board_screen.dart';
import 'bottom_bar.dart';
import 'theme.dart';

/// The Calendar page (v2 P4.2): the outline's calendar view — a LIST OF
/// DAYS in the app's row vocabulary, in one of two views:
///
///  - **week** (default): the 7 days of the shown week, Monday first
///    (the outline's `[Monday … 3]` list);
///  - **month**: every day of the shown month, same row shape.
///
/// A row reads `Monday … 3`: the day's name plus its interval count from
/// `store.dayItemCount(date)` — a READ THROUGH the placeholder (P4.1):
/// rendering the calendar never materializes a day and never writes a
/// `days` row. Counts are batch-loaded per shown range ([_reload]) and a
/// row whose count has not landed yet shows an empty slot.
///
/// Highlighting (P4.2 rule 2): TODAY's row carries the theme's highlight
/// tokens ([AppColors.highlight] fill + [AppColors.highlightBorder]
/// border) in place of the plain [AppDecorations.card] rows — and so does
/// the date-setter's chosen day, whose week/month also becomes the shown
/// range.
///
/// Navigation (rule 3): hover-revealed chevrons at the vertical center of
/// the left/right window edges — the touch-map's swipe replacement. They
/// live in SIDE GUTTERS laid out BESIDE the reading column (never over
/// the day list): left = previous week/month, right = next. Tapping a day
/// row opens THAT DAY'S BOARD through [AppController.init]'s `dayDate`
/// seam — a read-only open (P4.1; the fork happens on the day board's
/// first write — P4.3 completes the day-board story).
///
/// Own bar (P3.1's page-contextual bars): **home** (pop to the board
/// root) · **view toggle** (week ↔ month) · **date setter** (a popup
/// month-grid picker: the shown month's day numbers in a simple
/// 7-column grid with month stepping; picking a day sets the shown range
/// + the highlight).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen(this.controller, {super.key});

  /// The board's controller — the store/clock seam the page reads days
  /// through and day boards are opened from.
  final AppController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

/// Which list the page renders (P4.2: week is the default; a later
/// settings chunk flips the default).
enum _CalendarView { week, month }

class _CalendarScreenState extends State<CalendarScreen> {
  AppController get controller => widget.controller;
  Store get _store => controller.store;

  _CalendarView _view = _CalendarView.week;

  /// The day the shown range is anchored on: today at open, each chevron
  /// step moves it ±7 days (week) / ±1 month (month), and a date-setter
  /// pick lands it on the picked day (which is then highlighted).
  late DateTime _focus;

  /// The date-setter's chosen day — highlighted alongside today.
  DateTime? _chosen;

  /// The CURRENT shown days' counts (`dayNumber` → `dayItemCount`),
  /// swapped in atomically per [_reload].
  Map<int, int> _counts = const {};

  /// First load finished — the one loading frame (the Library's rule).
  bool _ready = false;

  /// Edge-chevron hover state (the reveal).
  bool _hoverLeft = false;
  bool _hoverRight = false;

  /// [_reload] generation: a stale count batch (a range change mid-
  /// flight) is dropped instead of overwriting the newer range's counts.
  int _reloadGeneration = 0;

  /// One day board at a time (the async init/push double-tap guard, the
  /// Library's plan-open guard).
  bool _openingDay = false;

  @override
  void initState() {
    super.initState();
    _focus = _today;
    unawaited(_reload());
  }

  // ── dates ──────────────────────────────────────────────────────────────

  /// Today: the clock's current instant read as a LOCAL calendar day
  /// (CONVENTORS §7), anchored at midnight — every date the page builds
  /// is a local `DateTime(y, m, d)` so `dayNumber` speaks the store's day
  /// and row equality is exact.
  DateTime get _today {
    final now = DateTime.fromMillisecondsSinceEpoch(
      controller.clock.now().millisecondsSinceEpoch,
    );
    return DateTime(now.year, now.month, now.day);
  }

  /// The days on screen: the 7 days of [_focus]'s week (Monday first —
  /// the outline's row order) in week view, every day of [_focus]'s month
  /// in month view.
  List<DateTime> _shownDays() {
    if (_view == _CalendarView.week) {
      final monday = _mondayOf(_focus);
      return [for (var i = 0; i < 7; i++) _addDays(monday, i)];
    }
    return [
      for (var day = 1; day <= _daysInMonth(_focus); day++)
        DateTime(_focus.year, _focus.month, day),
    ];
  }

  /// Batch-reads the shown days' counts through the placeholder
  /// (`dayItemCount` = resolve + tree read, NO writes — P4.1) and swaps
  /// them in atomically. Generational: a stale batch never lands.
  Future<void> _reload() async {
    final generation = ++_reloadGeneration;
    final counts = <int, int>{};
    for (final day in _shownDays()) {
      counts[dayNumber(day)] = await _store.dayItemCount(day);
    }
    if (!mounted || generation != _reloadGeneration) return;
    setState(() {
      _counts = counts;
      _ready = true;
    });
  }

  // ── actions ────────────────────────────────────────────────────────────

  /// Chevron paging: week steps ±7 CALENDAR days (pure date math — no
  /// `Duration`, DST must not eat a row), month steps ±1 month.
  void _page(int direction) {
    setState(() {
      _focus = _view == _CalendarView.week
          ? _addDays(_focus, 7 * direction)
          : _shiftMonths(_focus, direction);
    });
    unawaited(_reload());
  }

  void _toggleView() {
    setState(() {
      _view = _view == _CalendarView.week
          ? _CalendarView.month
          : _CalendarView.week;
    });
    unawaited(_reload());
  }

  /// The date setter (bar button): the popup month-grid picker over the
  /// SHOWN month; picking a day sets it as the chosen day, the shown
  /// range, and the highlight.
  Future<void> _openDateSetter() async {
    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.transparent, // effect only behind the menu
      builder: (dialogContext) => _MonthGridPicker(initial: _focus),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _chosen = picked;
      _focus = picked;
    });
    unawaited(_reload());
  }

  /// Tapping a day row: THAT DAY'S BOARD — a second [AppController]
  /// bound via P4.1's `dayDate` seam driving the standard [BoardScreen]
  /// with the plan bar's home/back (P4.3 replaces this with the full
  /// day-board story). The open is READ-ONLY: `init(dayDate:)` renders
  /// the resolved placeholder and materializes nothing. Disposed on pop
  /// (its 1 Hz ticker dies with it); the calendar reloads afterwards in
  /// case the day's plan was edited there.
  Future<void> _openDay(DateTime date) async {
    if (_openingDay) return;
    _openingDay = true;
    final dayController = AppController(
      store: controller.store,
      clock: controller.clock,
      notifier: controller.notifier,
      player: controller.player,
      soundsDir: controller.soundsDir,
      soundListing: controller.soundListing,
    );
    await dayController.init(dayDate: date);
    if (!mounted) {
      dayController.dispose();
      _openingDay = false;
      return;
    }
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => BoardScreen(dayController, bar: BoardBar.plan),
      ),
    );
    dayController.dispose();
    _openingDay = false;
    if (mounted) unawaited(_reload());
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('calendar-page'),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                // Same reading width as the board and editor (520).
                constraints: const BoxConstraints(maxWidth: 520),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Text(
                        'Calendar',
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
              ),
            ),
            const SizedBox(height: 4),
            // The reading column sits BETWEEN the chevron gutters, which
            // reach the window edges (stretch) and never cover the rows.
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _edgeNav(left: true),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 520,
                        child: _ready
                            ? _content()
                            : const SizedBox.shrink(), // one frame of loading
                      ),
                    ),
                  ),
                  _edgeNav(left: false),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _bar(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// The calendar bar: home · view toggle (week ↔ month) · date setter
  /// (P4.2 rule 5). The toggle's icon names the CURRENT view (the plan
  /// bar's visibility-toggle convention).
  Widget _bar(BuildContext context) {
    return BottomBar(
      key: const Key('calendar-bar'),
      buttons: [
        BarButton(
          buttonKey: const Key('bar-home'),
          icon: Icons.home,
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        BarButton(
          buttonKey: const Key('bar-view-toggle'),
          icon: _view == _CalendarView.week
              ? Icons.calendar_view_week
              : Icons.calendar_view_month,
          onPressed: _toggleView,
        ),
        BarButton(
          buttonKey: const Key('bar-date-setter'),
          icon: Icons.date_range,
          onPressed: _openDateSetter,
        ),
      ],
    );
  }

  /// One window-edge gutter (56px, touching the window edge): the mouse
  /// region REVEALS its chevron — hidden until the pointer enters the
  /// strip, [AnimatedOpacity] for the fade. The button sits at the
  /// gutter's vertical center, outside the reading column.
  Widget _edgeNav({required bool left}) {
    final revealed = left ? _hoverLeft : _hoverRight;
    return MouseRegion(
      key: Key(left ? 'cal-gutter-left' : 'cal-gutter-right'),
      onEnter: (_) => setState(() {
        if (left) {
          _hoverLeft = true;
        } else {
          _hoverRight = true;
        }
      }),
      onExit: (_) => setState(() {
        if (left) {
          _hoverLeft = false;
        } else {
          _hoverRight = false;
        }
      }),
      child: SizedBox(
        width: 56,
        child: Align(
          alignment: Alignment.center,
          child: AnimatedOpacity(
            key: Key(left ? 'cal-prev-reveal' : 'cal-next-reveal'),
            opacity: revealed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: BarButton(
              buttonKey: Key(left ? 'cal-prev' : 'cal-next'),
              icon: left ? Icons.chevron_left : Icons.chevron_right,
              onPressed: () => _page(left ? -1 : 1),
            ),
          ),
        ),
      ),
    );
  }

  /// The day list — a plain Column inside a scroll view so EVERY shown
  /// day is BUILT (the board's list-view rule: month view renders up to
  /// 31 rows and the row keys are addressable wherever they are).
  Widget _content() {
    final days = _shownDays();
    return SingleChildScrollView(
      key: const Key('calendar-list'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _dayRow(days[i]),
          ],
        ],
      ),
    );
  }

  /// One day row in the app's row vocabulary: the day's NAME top-left,
  /// its interval COUNT top-right (`Monday … 3` — plain digits, no
  /// suffix). TODAY and the date-setter's chosen day carry the
  /// highlight tokens; every other day is the plain card. Tap = that
  /// day's board.
  Widget _dayRow(DateTime day) {
    final iso = _iso(day);
    final highlighted = day == _today || day == _chosen;
    final count = _counts[dayNumber(day)];
    return GestureDetector(
      key: Key('day-$iso'),
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_openDay(day)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        clipBehavior: Clip.antiAlias, // the fill must not square corners
        decoration: highlighted ? _highlightDecoration : AppDecorations.card,
        child: Row(
          children: [
            Expanded(
              child: Text(
                _dayNames[day.weekday - 1],
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              count == null ? '' : '$count',
              key: Key('count-$iso'),
              style: const TextStyle(
                fontFamily: AppFonts.digits,
                fontSize: 14,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Today / chosen-day row fill + border (the P4.2 highlight tokens).
  static const BoxDecoration _highlightDecoration = BoxDecoration(
    borderRadius: BorderRadius.all(
      Radius.circular(AppDecorations.rectRadius),
    ),
    border: Border.fromBorderSide(
      BorderSide(color: AppColors.highlightBorder, width: AppDecorations.borderWidth),
    ),
    color: AppColors.highlight,
  );
}

/// The popup month-grid picker (P4.2 rule 4 — the outline's "html
/// calendar" open idea): the initial month's day numbers in a simple
/// 7-column grid (Monday-first letters row on top), stepped with the
/// header's chevrons. Tapping a day pops it back as the picked date.
class _MonthGridPicker extends StatefulWidget {
  const _MonthGridPicker({required this.initial});

  /// The day whose month the grid opens on (the calendar's shown range).
  final DateTime initial;

  @override
  State<_MonthGridPicker> createState() => _MonthGridPickerState();
}

class _MonthGridPickerState extends State<_MonthGridPicker> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month, 1);

  String get _label => '${_monthNames[_month.month - 1]} ${_month.year}';

  void _step(int direction) {
    setState(() => _month = _shiftMonths(_month, direction));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black, // opaque menu panel
      shape: AppDecorations.menuShape,
      title: const Text('Pick a day'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month header: step left / label / step right.
            Row(
              children: [
                BarButton(
                  buttonKey: const Key('cal-pick-prev'),
                  icon: Icons.chevron_left,
                  onPressed: () => _step(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _label,
                      key: const Key('cal-pick-month'),
                      style: const TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                BarButton(
                  buttonKey: const Key('cal-pick-next'),
                  icon: Icons.chevron_right,
                  onPressed: () => _step(1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // The Monday-first weekday letters.
            Row(
              children: [
                for (final letter in _weekdayLetters)
                  Expanded(
                    child: SizedBox(
                      height: 16,
                      child: Center(
                        child: Text(
                          letter,
                          style: const TextStyle(
                            fontFamily: AppFonts.ui,
                            fontSize: 11,
                            letterSpacing: 1,
                            color: AppColors.dimmed,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final row in _gridRows()) row,
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// The grid as weeks of 7 cells: leading blanks up to the 1st's
  /// weekday, then the month's days, the last row padded out.
  List<Widget> _gridRows() {
    final first = DateTime(_month.year, _month.month, 1);
    final cells = <Widget>[
      for (var i = 0; i < first.weekday - 1; i++) _blankCell(),
      for (var day = 1; day <= _daysInMonth(_month); day++) _dayCell(day),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final end = i + 7 <= cells.length ? i + 7 : cells.length;
      rows.add(
        Row(
          children: [
            ...cells.sublist(i, end),
            for (var k = end; k < i + 7; k++) _blankCell(),
          ],
        ),
      );
    }
    return rows;
  }

  Widget _blankCell() => const Expanded(child: SizedBox(height: 34));

  Widget _dayCell(int day) {
    final date = DateTime(_month.year, _month.month, day);
    return Expanded(
      child: SizedBox(
        height: 34,
        child: GestureDetector(
          key: Key('pick-${_iso(date)}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(date),
          child: Center(
            child: Text(
              '$day',
              style: const TextStyle(
                fontFamily: AppFonts.digits,
                fontSize: 14,
                color: AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Row vocabulary names (CONVENTIONS §7 — English UI copy): the week
/// starts on Monday, both here and in every view's row order.
const List<String> _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The grid's Monday-first column letters.
const List<String> _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// The Monday of [date]'s week (Dart weeks start on Monday).
DateTime _mondayOf(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

/// Pure CALENDAR day arithmetic at local midnight — a `Duration` add
/// would drift a day across a DST transition.
DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// [date]'s month moved by [months]; the anchor day clamps into a
/// shorter target month (Jan 31 → Feb 28) instead of rolling over.
DateTime _shiftMonths(DateTime date, int months) {
  final total = date.year * 12 + (date.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
}

/// How many days [date]'s month has.
int _daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;

/// The shared local ISO day form (CONVENTIONS §7) — row and cell keys.
String _iso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

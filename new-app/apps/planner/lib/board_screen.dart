import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:planner_engine/planner_engine.dart';

import 'app_controller.dart';
import 'editor_controller.dart';
import 'editor_screen.dart';
import 'format.dart';
import 'interval_rows.dart';
import 'keyboard_nav.dart';
import 'theme.dart';
import 'time_adjust_modal.dart';

/// The main board screen (v2 P2.1): the state-driven readout on top, the
/// interval LIST as the main area (the editor's row vocabulary over the
/// authored tree — completion checkboxes, live duration slots, left→right
/// progress fills), the control row (adjust, reset, skip), and the
/// pulsing tap-to-continue affordance while the run holds at a zeroed
/// manually-complete instance.
///
/// Interaction is a single context action dispatched by snapshot state —
/// start / pause / resume / skip — reachable both by tapping the readout
/// and by pressing Space. Right-clicking the readout opens the (P4.1)
/// editor; right-clicking an interval ROW jumps the run to it (P2.3 —
/// direct, no confirm step; the interval-picker overlay is gone). The
/// dial is GONE (P2.1): the list is the board.
///
/// No menu/gear buttons in the header: multi-board switching and settings
/// are out of v1 scope.
class BoardScreen extends StatefulWidget {
  const BoardScreen(this.controller, {super.key});

  final AppController controller;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  AppController get controller => widget.controller;

  /// Keyboard model (acceptance): one section — the control buttons.
  late final ScreenNav _nav = ScreenNav(sections: const []);

  /// v2 P2.3 — the list's scroll plumbing: both the center-snap of the
  /// current row and the return after a manual scroll drive this
  /// controller.
  final ScrollController _listScroll = ScrollController();

  /// The list's viewport box and every DEF row's box (GlobalKeys) — the
  /// centering math measures them wherever the cursor is.
  final GlobalKey _listKey = GlobalKey(debugLabel: 'interval-list-viewport');
  final Map<String, GlobalKey> _rowKeys = {};

  /// The cursor the list was last centered for (null = "no current
  /// instance"); a build whose cursor differs re-centers post-frame.
  int? _centeredOrdinal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NavKeyboard(
        nav: _nav,
        onKey: _onKey,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // The list reads at the editor's column width (520) — rows
              // like the editor's, on a wide desktop window.
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListenableBuilder(
                listenable: Listenable.merge([controller, _nav]),
                builder: (context, _) => _buildBoard(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    // Rebuilt with the state (ListenableBuilder) — the keyboard cells'
    // enabled flags (e.g. skip) must track it.
    _nav.updateSections(_sections());
    final snapshot = controller.snapshot;
    final timerColor = hexColor(controller.timer.color);
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Board name hidden for v1 (single board — kept for future
        // multi-board versions, acceptance "Remove the Board Name").
        // Text(
        //   controller.board.name,
        //   textAlign: TextAlign.center,
        //   style: const TextStyle(
        //     fontFamily: AppFonts.ui,
        //     fontSize: 17,
        //     fontWeight: FontWeight.w700,
        //     color: AppColors.text,
        //   ),
        // ),
        const SizedBox(height: 16),
        _readoutDisplay(context, snapshot, timerColor),
        const SizedBox(height: 12),
        // P2.1: the dial is gone — the interval LIST is the main area.
        Expanded(child: _intervalList(snapshot)),
        const SizedBox(height: 12),
        // v2 P2.2: Retry missed — the residue of a partial run. The
        // engine's fly-past makes a plain start re-run ONLY the
        // un-completed items (marks are the record; Reset clears them).
        if (_retryMissedCount(snapshot) case final n when n != null) ...[
          TextButton(
            key: const Key('btn-retry-missed'),
            onPressed: () => controller.start(),
            child: Text(
              'Retry missed ($n)',
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 15,
                color: AppColors.lightBlue,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        _controlRow(context, snapshot),
        if (snapshot.state == SessionState.awaitingAdvance) ...[
          const SizedBox(height: 12),
          _tapToContinue(),
        ],
        // The next-interval caption is gone (acceptance: it was MultiTimer's
        // advance button stand-in — the '>' control replaced it).
        const SizedBox(height: 24),
      ],
    );
  }

  /// The state-driven readout — kept whole for now (P2.4 slims it into a
  /// header above the list). Tapping it dispatches the context action and
  /// right-clicking it opens the editor: the old dial's affordances, now
  /// on the display itself.
  Widget _readoutDisplay(
    BuildContext context,
    TimerSnapshot snapshot,
    Color timerColor,
  ) {
    return GestureDetector(
      key: const Key('readout'),
      behavior: HitTestBehavior.opaque,
      onTap: dispatchContextAction,
      onSecondaryTapDown: (_) => _openEditor(context),
      child: _readout(snapshot, timerColor),
    );
  }

  /// P2.1 — the board's main area: the interval LIST over the authored
  /// tree (defs and groups — the editor's rows, NOT the flattened
  /// occurrences), each row mapped onto the live run: completion
  /// checkbox, live duration slot, left→right progress fill, and
  /// semi-transparency for completed/passed rows.
  ///
  /// v2 P2.3 — scroll behavior: the current row rides as close to the
  /// viewport's center as the list allows (first row → top, last row →
  /// bottom, a list that fits → no scrolling), re-centering whenever the
  /// cursor moves, and animating back after every scroll gesture ends.
  Widget _intervalList(TimerSnapshot snapshot) {
    final occurrences = <String, List<int>>{};
    for (final i in controller.instances) {
      (occurrences[i.defId] ??= []).add(i.ordinal);
    }
    if (_centeredOrdinal != snapshot.ordinal) {
      _centeredOrdinal = snapshot.ordinal;
      // Post-frame: the rows must be laid out before they can be
      // measured against the viewport.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerCurrentRow();
      });
    }
    return NotificationListener<ScrollNotification>(
      key: _listKey,
      onNotification: _onListScrollNotification,
      child: ListView(
        key: const Key('interval-list'),
        controller: _listScroll,
        // The interval list is hand-authored and short: a generous cache
        // keeps every row built so the centering math can always measure
        // the current row, wherever the user has browsed.
        scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: _treeRows(controller.tree.roots, occurrences, snapshot),
      ),
    );
  }

  /// v2 P2.3 — the v2 stand-in for the magnetized scroll: when a scroll
  /// gesture ENDS, animate back to the current row's best position (the
  /// fancy scroll physics are v3). The post-frame hop matters twice over:
  /// the notification fires inside the scroll position's activity swap,
  /// and the rows' positions are only fresh after the next layout.
  bool _onListScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerCurrentRow();
      });
    }
    return false; // keep bubbling — other listeners may care
  }

  /// v2 P2.3 — scroll so the CURRENT row's center sits at the viewport's
  /// center, clamped to the scroll extent: the first row can only reach
  /// the top, the last the bottom, and a list that fits never scrolls.
  void _centerCurrentRow() {
    if (!_listScroll.hasClients) return;
    final position = _listScroll.position;
    final ordinal = controller.snapshot.ordinal;
    if (ordinal == null ||
        ordinal < 0 ||
        ordinal >= controller.instances.length) {
      return; // no current instance — nothing to center on
    }
    final rowContext =
        _rowKeys[controller.instances[ordinal].defId]?.currentContext;
    final listContext = _listKey.currentContext;
    if (rowContext == null || listContext == null) return;
    final rowBox = rowContext.findRenderObject();
    final listBox = listContext.findRenderObject();
    if (rowBox is! RenderBox || listBox is! RenderBox) return;
    if (!rowBox.attached ||
        !listBox.attached ||
        !rowBox.hasSize ||
        !listBox.hasSize) {
      return;
    }
    final rowTop = rowBox.localToGlobal(Offset.zero).dy;
    final listTop = listBox.localToGlobal(Offset.zero).dy;
    final target = (position.pixels +
            (rowTop - listTop) +
            rowBox.size.height / 2 -
            listBox.size.height / 2)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    // Already there — this also absorbs our own return animations ending.
    if ((target - position.pixels).abs() < 0.5) return;
    unawaited(
      position.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      ),
    );
  }

  /// One row per tree node (8px between entries — the editor's rhythm),
  /// recursing into groups.
  List<Widget> _treeRows(
    List<IntervalNode> nodes,
    Map<String, List<int>> occurrences,
    TimerSnapshot snapshot,
  ) {
    final rows = <Widget>[
      for (final node in nodes)
        switch (node) {
          DefNode(:final def) => _defRow(def, occurrences, snapshot),
          GroupNode(:final group, :final children) =>
            _groupRow(group, children, occurrences, snapshot),
        },
    ];
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        rows[i],
      ],
    ];
  }

  /// One authored interval: completion checkbox | chip card whose duration
  /// slot is LIVE (`<left>/<total>` for the current occurrence, `wait` at
  /// a hold, the wall countdown, `15:30`/duration/`open` otherwise) over
  /// the left→right progress fill. A fully-marked item or a row whose
  /// occurrences have all passed renders semi-transparent — the dial's
  /// dimmed ticks, as rows (the shared [AppColors.dimmed] alpha).
  Widget _defRow(
    IntervalDef def,
    Map<String, List<int>> occurrences,
    TimerSnapshot snapshot,
  ) {
    final ordinals = occurrences[def.id] ?? const <int>[];
    final cursor = snapshot.ordinal;
    final isCurrent = cursor != null && ordinals.contains(cursor);
    final suspendedAt = snapshot.suspendedOrdinal;
    final isSuspended = suspendedAt != null && ordinals.contains(suspendedAt);
    final completed = controller.session.isCompleted(def.id);
    final passed = cursor != null &&
        ordinals.isNotEmpty &&
        !isSuspended &&
        ordinals.every((o) => o < cursor);
    final hold = isCurrent && snapshot.state == SessionState.awaitingAdvance;
    final color = hexColor(def.color);

    final row = Opacity(
      key: Key('row-${def.id}'),
      opacity: (completed || passed) ? AppColors.dimmed.a : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RowCircle(
            key: Key('check-${def.id}'),
            checked: completed,
            onTap: ordinals.isEmpty
                ? null
                : () => controller.toggleMark(ordinals.first),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                IntervalChipCard(
                  def: def,
                  shape: _defTime(def, ordinals, snapshot),
                  shapeKey: Key('time-${def.id}'),
                  badge: isCurrent && snapshot.late ? 'late' : null,
                  fillFraction: _defFraction(ordinals, snapshot),
                  fillColor: color.withValues(alpha: 0.3),
                  fillKey: Key('fill-${def.id}'),
                  bordered: !hold,
                ),
                if (hold)
                  // The "» tap to continue" pulse vocabulary, on the held
                  // row's border (the card's static border stands down).
                  Positioned.fill(
                    key: Key('hold-pulse-${def.id}'),
                    child: _Pulse(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(AppDecorations.rectRadius),
                          ),
                          border: Border.all(
                            color: color,
                            width: AppDecorations.borderWidth,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      key: _rowKeys.putIfAbsent(
        def.id,
        () => GlobalKey(debugLabel: 'row-${def.id}'),
      ),
      behavior: HitTestBehavior.opaque,
      // v2 P2.3: right-click = jump straight to this item's target
      // occurrence — direct, no confirmation (the interval-picker
      // overlay is gone).
      onSecondaryTapDown: (_) => _jumpToRow(ordinals),
      child: row,
    );
  }

  /// v2 P2.3 — right-click jump: a board row is a DEF, so pick its target
  /// occurrence — the first at or after the cursor, else the last (the
  /// v1 `jumpTo` semantics the old picker used; jump-to-same restarts the
  /// instance). Running keeps running at the target, a paused run parks
  /// paused-ready.
  void _jumpToRow(List<int> ordinals) {
    if (ordinals.isEmpty) return;
    final cursor = controller.snapshot.ordinal;
    final target = cursor == null
        ? ordinals.first
        : ordinals.firstWhere((o) => o >= cursor, orElse: () => ordinals.last);
    controller.jumpTo(target);
  }

  /// The duration slot's LIVE text: `wait` at a hold on the current row,
  /// the wall countdown while the run awaits a pending wall, the current
  /// occurrence's `<left>/<total>` (e.g. `10m5s/15m` — the total is that
  /// occurrence's effective duration), the suspended occurrence's frozen
  /// `<left>/<total>`, else the authored shape (`15:30` / duration /
  /// `open` — [rowShape]).
  String _defTime(
    IntervalDef def,
    List<int> ordinals,
    TimerSnapshot snapshot,
  ) {
    final cursor = snapshot.ordinal;
    if (cursor != null && ordinals.contains(cursor)) {
      if (snapshot.state == SessionState.awaitingAdvance) return 'wait';
      if (snapshot.state == SessionState.awaitingWall) {
        // The countdown TO the wall is the meaningful clock here.
        return formatDurationCompact(snapshot.remaining ?? Duration.zero);
      }
      final total = Duration(
        seconds: controller.instances[cursor].durationSeconds ?? 0,
      );
      if (total == Duration.zero) return 'open'; // an Open row parked current
      final left = snapshot.remaining ?? total;
      return '${formatDurationCompact(left)}/${formatDurationCompact(total)}';
    }
    final suspendedAt = snapshot.suspendedOrdinal;
    if (suspendedAt != null && ordinals.contains(suspendedAt)) {
      final total = Duration(
        seconds: controller.instances[suspendedAt].durationSeconds ?? 0,
      );
      if (total == Duration.zero) return 'open';
      final left = snapshot.suspendedRemaining ?? Duration.zero;
      return '${formatDurationCompact(left)}/${formatDurationCompact(total)}';
    }
    return rowShape(def);
  }

  /// The row's progress fill: the current occurrence's elapsed/effective,
  /// 1.0 once every occurrence has passed (a held-at-zero occurrence
  /// counts as fully consumed), 0 for future rows, a pending wall
  /// (awaitingWall), and a fresh run.
  double _defFraction(List<int> ordinals, TimerSnapshot snapshot) {
    final cursor = snapshot.ordinal;
    if (cursor == null || ordinals.isEmpty) return 0;
    if (ordinals.contains(cursor)) {
      switch (snapshot.state) {
        case SessionState.notStarted:
          return 0;
        case SessionState.awaitingAdvance:
          return 1; // held AT zero — the occurrence consumed its length
        case SessionState.awaitingWall:
          return 0; // the wall has not fired yet
        case SessionState.running:
        case SessionState.paused:
          final total =
              (controller.instances[cursor].durationSeconds ?? 0) * 1000;
          if (total <= 0) return 0;
          final left = snapshot.remaining?.inMilliseconds ?? total;
          return ((total - left) / total).clamp(0.0, 1.0);
      }
    }
    final suspendedAt = snapshot.suspendedOrdinal;
    if (suspendedAt != null && ordinals.contains(suspendedAt)) {
      final total =
          (controller.instances[suspendedAt].durationSeconds ?? 0) * 1000;
      if (total <= 0) return 0;
      final left = snapshot.suspendedRemaining?.inMilliseconds ?? total;
      return ((total - left) / total).clamp(0.0, 1.0);
    }
    return ordinals.every((o) => o < cursor) ? 1 : 0;
  }

  /// One group, rendered like the editor's group rows (bracket + nested
  /// children): the repeat counter counts DOWN (repeats LEFT) and the
  /// group block carries the aggregate fill across its occurrences (the
  /// per-repeat segmented fill is v3 polish).
  Widget _groupRow(
    GroupDef group,
    List<IntervalNode> children,
    Map<String, List<int>> occurrences,
    TimerSnapshot snapshot,
  ) {
    final (:defIds, :ordinals) = _subtree(children, occurrences);
    final cursor = snapshot.ordinal;
    final suspendedAt = snapshot.suspendedOrdinal;
    final isSuspended = suspendedAt != null && ordinals.contains(suspendedAt);
    final completed =
        defIds.isNotEmpty && defIds.every(controller.session.isCompleted);
    final passed = cursor != null &&
        ordinals.isNotEmpty &&
        !isSuspended &&
        ordinals.every((o) => o < cursor);

    return Opacity(
      key: Key('row-${group.id}'),
      opacity: (completed || passed) ? AppColors.dimmed.a : 1.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RowCircle(key: Key('check-${group.id}'), checked: completed),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: RowFill(
                    key: Key('fill-${group.id}'),
                    fraction: _groupFraction(ordinals, snapshot),
                    color: AppColors.outline,
                  ),
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GroupBracketBar(
                        key: Key('bracket-${group.id}'),
                        repeatKey: Key('repeat-${group.id}'),
                        repeatLabel:
                            '${_repeatsLeft(group, children, ordinals, snapshot)}',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _treeRows(children, occurrences, snapshot),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Def ids + flattened ordinals of a group's subtree — the ordinals are
  /// SORTED because nested repeats interleave the per-def occurrence
  /// lists (the pass structure is only visible in ordinal order).
  ({List<String> defIds, List<int> ordinals}) _subtree(
    List<IntervalNode> nodes,
    Map<String, List<int>> occurrences,
  ) {
    final defIds = <String>[];
    final ordinals = <int>[];
    void walk(List<IntervalNode> ns) {
      for (final n in ns) {
        switch (n) {
          case DefNode(:final def):
            defIds.add(def.id);
            ordinals.addAll(occurrences[def.id] ?? const <int>[]);
          case GroupNode(:final children):
            walk(children);
        }
      }
    }

    walk(nodes);
    ordinals.sort();
    return (defIds: defIds, ordinals: ordinals);
  }

  /// The group's aggregate progress: every passed occurrence in full, plus
  /// the current/suspended occurrence's elapsed part, over the subtree's
  /// total duration (Open occurrences add nothing).
  double _groupFraction(List<int> ordinals, TimerSnapshot snapshot) {
    final cursor = snapshot.ordinal;
    if (cursor == null || ordinals.isEmpty) return 0;
    var total = 0;
    var done = 0;
    for (final o in ordinals) {
      final planned = (controller.instances[o].durationSeconds ?? 0) * 1000;
      total += planned;
      if (o == cursor) {
        final left = switch (snapshot.state) {
          SessionState.running || SessionState.paused =>
            snapshot.remaining?.inMilliseconds ?? planned,
          SessionState.awaitingAdvance => 0, // held AT zero: consumed
          SessionState.awaitingWall => planned, // not fired: nothing elapsed
          SessionState.notStarted => planned,
        };
        done += (planned - left).clamp(0, planned);
      } else if (o == snapshot.suspendedOrdinal) {
        final left = snapshot.suspendedRemaining?.inMilliseconds ?? planned;
        done += (planned - left).clamp(0, planned);
      } else if (o < cursor) {
        done += planned;
      }
    }
    if (total <= 0) return ordinals.every((o) => o < cursor) ? 1 : 0;
    return (done / total).clamp(0.0, 1.0);
  }

  /// Repeats LEFT for a group row — the editor's total count counting
  /// down: the group's own pass index under the cursor (nested repeats
  /// cycle the counter once per enclosing pass). Fresh run → the full
  /// count; the cursor past every pass → 0.
  int _repeatsLeft(
    GroupDef group,
    List<IntervalNode> children,
    List<int> ordinals,
    TimerSnapshot snapshot,
  ) {
    final repeat = group.repeatCount;
    final cursor = snapshot.ordinal;
    if (cursor == null || ordinals.isEmpty) return repeat;
    final at = ordinals.indexOf(cursor);
    if (at < 0) return ordinals.every((o) => o < cursor) ? 0 : repeat;
    final perPass = flatten(IntervalTree(children)).length;
    if (perPass <= 0) return repeat;
    final ownPass = (at ~/ perPass) % repeat;
    return repeat - ownPass;
  }

  /// Center readout: the planned `03H : 00M / 00` layout before a run, the
  /// running countdown (with PAUSED/WAIT state chip) during one.
  Widget _readout(TimerSnapshot snapshot, Color timerColor) {
    switch (snapshot.state) {
      case SessionState.notStarted:
        final (hours, minutes, seconds) = formatPlannedParts(
          snapshot.totalPlanned,
        );
        return _PlannedReadout(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          color: timerColor,
        );
      case SessionState.running:
      case SessionState.paused:
      case SessionState.awaitingAdvance:
      case SessionState.awaitingWall: // v2 P1.4: the countdown to the wall
        return _RunReadout(snapshot: snapshot);
    }
  }

  /// `≫ next interval` caption — shown iff an instance follows the cursor
  /// (at notStarted the first instance is "next").
  /// The next-interval caption: retired per acceptance (the '>' skip
  /// control replaced this MultiTimer-era advance hint). Code kept for
  /// possible future use.
  // ignore: unused_element
  Widget _caption(TimerSnapshot snapshot) {
    final nextIndex = (snapshot.ordinal ?? -1) + 1;
    if (nextIndex >= controller.instances.length) {
      return const SizedBox.shrink();
    }
    final next = controller.instances[nextIndex];
    return Row(
      key: const Key('caption'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.double_arrow, size: 18, color: AppColors.lightBlue),
        const SizedBox(width: 4),
        Text(
          '${formatInstanceLabel(next.ordinal, next.name)} - '
          '${formatDuration(Duration(seconds: next.durationSeconds ?? 0))}',
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 17,
            color: AppColors.lightBlue,
          ),
        ),
      ],
    );
  }

  /// v2 P2.2 — how many ITEMS (defs) a retry would redo: shown only when
  /// the run is over with a partial residue (some done, some not). Null =
  /// no button (fresh timer: nothing to "retry"; fully done: nothing left).
  int? _retryMissedCount(TimerSnapshot snapshot) {
    if (snapshot.state != SessionState.notStarted) return null;
    final items = controller.instances.map((i) => i.defId).toSet();
    if (items.isEmpty) return null;
    final missed = items
       .where((id) => !controller.session.isCompleted(id))
        .length;
    if (missed == 0 || missed == items.length) return null;
    return missed;
  }

  /// Control row under the list: adjust the current time, reset (with
  /// confirmation), and skip. Skip is disabled ONLY at notStarted —
  /// there is nothing to skip before a run begins; every other state
  /// (running, paused, awaitingAdvance) skips.
  Widget _controlRow(BuildContext context, TimerSnapshot snapshot) {
    final canSkip = snapshot.state != SessionState.notStarted;
    final inLimbo = snapshot.state == SessionState.awaitingAdvance;
    const gap = SizedBox(width: 8);
    // Tweaks #5: in limbo the row keeps the shared buttons in their
    // usual slots — only Skip is swapped out, and Silence alarm takes
    // its place on the far right (tap-to-continue completes the hold).
    if (inLimbo) {
      return Row(
        key: const Key('control-row'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _HoverIconButton(
            circularRing: true,
            buttonKey: const Key('btn-adjust'),
            icon: Icons.schedule,
            focused: _nav.isFocused('btn-adjust'),
            onPressed: () => _openAdjust(context),
          ),
          gap,
          // v2 P2.2: the hold's second slot is the "not completed"
          // decision (the interval-list shortcut steps aside here).
          _HoverIconButton(
            circularRing: true,
            buttonKey: const Key('btn-not-completed'),
            icon: Icons.remove_done,
            focused: _nav.isFocused('btn-not-completed'),
            onPressed: () => controller.resolveHold(completed: false),
          ),
          gap,
          _HoverIconButton(
            circularRing: true,
            buttonKey: const Key('btn-reset'),
            icon: Icons.close_outlined,
            color: AppColors.danger, // destructive (greyscale-UI rule)
            focused: _nav.isFocused('btn-reset'),
            onPressed: () => _showResetDialog(context),
          ),
          gap,
          _HoverIconButton(
            circularRing: true,
            buttonKey: const Key('btn-silence'),
            icon: Icons.alarm_off,
            focused: _nav.isFocused('btn-silence'),
            onPressed: () => controller.silenceAlarm(),
          ),
        ],
      );
    }
    return Row(
      key: const Key('control-row'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _HoverIconButton(
          circularRing: true,
          buttonKey: const Key('btn-adjust'),
          icon: Icons.schedule,
          focused: _nav.isFocused('btn-adjust'),
          onPressed: canSkip ? () => _openAdjust(context) : null,
        ),
        gap,
        _HoverIconButton(
          circularRing: true,
          buttonKey: const Key('btn-reset'),
          icon: Icons.close_outlined,
          color: AppColors.danger, // destructive (greyscale-UI rule)
          focused: _nav.isFocused('btn-reset'),
          onPressed: () => _showResetDialog(context),
        ),
        gap,
        _HoverIconButton(
          circularRing: true,
          buttonKey: const Key('btn-skip'),
          icon: Icons.chevron_right,
          focused: _nav.isFocused('btn-skip'),
          onPressed: canSkip ? () => controller.skipNext() : null,
        ),
      ],
    );
  }

  /// Tweaks #7: the "+/- time" menu — the signed delta lands on the
  /// current instance's remaining for this run only.
  Future<void> _openAdjust(BuildContext context) async {
    final deltaSeconds = await showTimeAdjustModal(context);
    if (deltaSeconds != null && deltaSeconds != 0) {
      controller.adjustTime(deltaSeconds);
    }
  }

  /// Opens the timer editor over a freshly loaded tree; Done in the
  /// editor commits and reloads the board's session (onDone). The
  /// readout's right-click and Escape share this path.
  Future<void> _openEditor(BuildContext context) async {
    final tree = await controller.store.loadTree(controller.timer.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => EditorScreen(
          controller: EditorController(
            store: controller.store,
            timer: controller.timer,
            initialTree: tree,
          ),
          soundsDir: controller.soundsDir,
          soundListing: controller.soundListing,
          player: controller.player,
          onDone: () => controller.applyTreeEdit(), // tweaks #8: keep the run
        ),
      ),
    );
  }

  /// Reset confirmation: nothing happens without an explicit confirm —
  /// Cancel and the barrier tap just dismiss.
  void _showResetDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent, // effect only behind the menu
      builder: (dialogContext) {
        // Keyboard: focus starts on Cancel; arrows move Cancel <-> Reset,
        // Enter activates, Escape = Cancel (DismissIntent pops).
        final nav = ScreenNav(
          sections: [
            NavSection(id: 'actions', cells: [
              NavCell(
                id: 'dialog-cancel',
                row: 0,
                col: 0,
                activate: () => Navigator.of(dialogContext).pop(),
              ),
              NavCell(
                id: 'dialog-confirm',
                row: 0,
                col: 1,
                activate: () {
                  controller.reset();
                  Navigator.of(dialogContext).pop();
                },
              ),
            ]),
          ],
        )..focusSection(0);
        return NavKeyboard(
          nav: nav,
          child: ListenableBuilder(
            listenable: nav,
            builder: (_, _) => AlertDialog(
              backgroundColor: Colors.black, // opaque menu panel
              shape: AppDecorations.menuShape,
              title: const Text('Reset timer?'),
              content: const Text(
                'The current run will end and the timer returns to not '
                'started.',
              ),
              actions: [
                FocusRing(
                  focused: nav.isFocused('dialog-cancel'),
                  child: TextButton(
                    key: const Key('dialog-cancel'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                FocusRing(
                  focused: nav.isFocused('dialog-confirm'),
                  child: TextButton(
                    key: const Key('dialog-confirm'),
                    onPressed: () {
                      controller.reset();
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text(
                      'Reset',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Awaiting-advance affordance: REPLACES the caption while the run holds
  /// at a zeroed manually-complete instance — tap to advance (which resets
  /// to fresh notStarted at the end of the list).
  Widget _tapToContinue() {
    return GestureDetector(
      key: const Key('tap-to-continue'),
      // v2 P2.2: the tap completes (✓) — same as Enter/Space at a hold.
      onTapDown: (_) => controller.resolveHold(completed: true),
      child: _Pulse(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.double_arrow,
              size: 18,
              color: AppColors.text,
            ),
            const SizedBox(width: 4),
            const Text(
              'tap to continue',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 17,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The one context action, dispatched by snapshot state — the readout
  /// tap and Space both land here.
  void dispatchContextAction() {
    switch (controller.snapshot.state) {
      case SessionState.notStarted:
        controller.start();
      case SessionState.running:
        controller.pause();
      case SessionState.paused:
        controller.resume();
      case SessionState.awaitingAdvance:
        // v2 P2.2: the dial/Space action at a hold IS the completion
        // decision — Enter = completed, exactly like the tap-to-continue.
        controller.resolveHold(completed: true);
      case SessionState.awaitingWall: // v2 P1.4: skip the waited wall
        controller.skipNext();
    }
  }

  /// Board keyboard model (acceptance): Space = the context action; the
  /// arrows/Home/End/Enter walk the control buttons (shared model); the
  /// quick keys hit the buttons directly — Delete = reset, Ctrl+Right =
  /// next, Escape = the timer editor; v2 P2.3 Alt+↑/↓ jumps between
  /// intervals (the list owns navigation now — Tab opens nothing).
  KeyEventResult? _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    // Space down = the context action (held Space must not flap —
    // KeyRepeatEvents never reach here).
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      dispatchContextAction();
      return KeyEventResult.handled;
    }
    // v2 P2.3: Alt+Up/Down walks the RUN — jump to the occurrence
    // adjacent to the cursor (the right-click jump's keyboard parity;
    // the interval-picker overlay it replaces is gone).
    if (HardwareKeyboard.instance.isAltPressed &&
        (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown)) {
      _jumpToAdjacent(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _showResetDialog(context);
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.arrowRight) {
      if (controller.snapshot.state != SessionState.notStarted) {
        controller.skipNext();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _openEditor(context);
      return KeyEventResult.handled;
    }
    // v2 P2.2: at a hold Enter is THE completion decision (the user rule)
    // and N is the "not completed" button — both supersede the shared
    // button model only while the run holds.
    if (controller.snapshot.state == SessionState.awaitingAdvance) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        controller.resolveHold(completed: true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyN) {
        controller.resolveHold(completed: false);
        return KeyEventResult.handled;
      }
    }
    return null; // arrows/Home/End/Enter -> the shared button model
  }

  /// v2 P2.3 — Alt+↑/↓: jump to the occurrence adjacent to the cursor
  /// (±1 over the flattened run). No current instance, or a target past
  /// either end: nothing moves, but the key stays swallowed so the
  /// button-walk model does not steal it.
  void _jumpToAdjacent(int delta) {
    final cursor = controller.snapshot.ordinal;
    if (cursor == null) return;
    final target = cursor + delta;
    if (target < 0 || target >= controller.instances.length) return;
    controller.jumpTo(target);
  }

  @override
  void dispose() {
    _listScroll.dispose();
    super.dispose();
  }

  /// The control buttons as keyboard cells (one row).
  List<NavSection> _sections() {
    final state = controller.snapshot.state;
    final canSkip = state != SessionState.notStarted;
    if (state == SessionState.awaitingAdvance) {
      // The limbo row (tweaks #5) mirrors the row's second mode.
      return [
        NavSection(id: 'controls', cells: [
          NavCell(
            id: 'btn-adjust',
            row: 0,
            col: 0,
            activate: () => _openAdjust(context),
          ),
          NavCell(
            id: 'btn-not-completed',
            row: 0,
            col: 1,
            activate: () => controller.resolveHold(completed: false),
          ),
          NavCell(
            id: 'btn-reset',
            row: 0,
            col: 2,
            activate: () => _showResetDialog(context),
          ),
          NavCell(
            id: 'btn-silence',
            row: 0,
            col: 3,
            activate: () => controller.silenceAlarm(),
          ),
        ]),
      ];
    }
    return [
      NavSection(id: 'controls', cells: [
        NavCell(
          id: 'btn-adjust',
          row: 0,
          col: 0,
          enabled: canSkip,
          activate: () => _openAdjust(context),
        ),
        NavCell(
          id: 'btn-reset',
          row: 0,
          col: 1,
          activate: () => _showResetDialog(context),
        ),
        NavCell(
          id: 'btn-skip',
          row: 0,
          col: 2,
          enabled: canSkip,
          activate: () => controller.skipNext(),
        ),
      ]),
    ];
  }
}

/// Not-started readout: `03H : 00M` big with a small seconds subscript —
/// the mock's `_DialReadout` layout, in the timer color.
class _PlannedReadout extends StatelessWidget {
  const _PlannedReadout({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.color,
  });

  final String hours;
  final String minutes;
  final String seconds;
  final Color color;

  TextStyle _big(double size) => TextStyle(
    fontFamily: AppFonts.digits,
    fontWeight: FontWeight.w500,
    fontSize: size,
    height: 1.0,
    color: color,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(hours, style: _big(72)),
        const SizedBox(width: 3),
        Text('H', style: _big(24)),
        const SizedBox(width: 8),
        Text(':', style: _big(72)),
        const SizedBox(width: 8),
        Text(minutes, style: _big(72)),
        const SizedBox(width: 3),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('M', style: _big(24)),
            const SizedBox(height: 2),
            Text(seconds, style: _big(20)),
          ],
        ),
      ],
    );
  }
}

/// Run readout: dimmed `hm` total on top, big `mm:ss` with an optional
/// PAUSED/WAIT chip, a hairline divider, and the current instance label.
class _RunReadout extends StatelessWidget {
  const _RunReadout({required this.snapshot});

  final TimerSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final chip = switch (snapshot.state) {
      SessionState.paused => const _StateChip('PAUSED'),
      SessionState.awaitingAdvance => const _StateChip('WAIT'),
      _ => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatHm(snapshot.totalRemaining),
          style: const TextStyle(
            fontFamily: AppFonts.digits,
            fontWeight: FontWeight.w500,
            fontSize: 20,
            height: 1.0,
            color: AppColors.dimmed,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              formatMmSs(snapshot.remaining ?? Duration.zero),
              style: const TextStyle(
                fontFamily: AppFonts.digits,
                fontWeight: FontWeight.w500,
                fontSize: 60,
                height: 1.0,
                color: AppColors.text,
              ),
            ),
            if (chip != null) ...[const SizedBox(width: 12), chip],
          ],
        ),
        const SizedBox(height: 8),
        const SizedBox(
          width: 120,
          child: Divider(thickness: 1, height: 1, color: AppColors.outline),
        ),
        const SizedBox(height: 8),
        Text(
          formatInstanceLabel(snapshot.ordinal ?? 0, snapshot.currentLabel),
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 17,
            color: AppColors.dimmed,
          ),
        ),
      ],
    );
  }
}

/// Pulsing opacity (0.35 ↔ 1.0, 900ms, reverse repeat) for the
/// awaiting-advance "tap to continue" affordance.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller.drive(Tween<double>(begin: 0.35, end: 1.0)),
    child: widget.child,
  );
}

/// Control-row icon button: NO resting background — a circular HOVER
/// highlight appears on hover and is "just a touch bigger" than the icon
/// (acceptance). The hover circle shows even when the action is disabled
/// (the "next" button was the complaint), and there is no tooltip text.
class _HoverIconButton extends StatefulWidget {
  const _HoverIconButton({
    required this.buttonKey,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.text,
    this.focused = false,
    this.circularRing = true,
  });

  /// Lives on the INNER IconButton (tests address the button by key).
  final Key buttonKey;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  /// Keyboard-focus ring (acceptance keyboard navigation).
  final bool focused;

  /// Round buttons get a circular ring.
  final bool circularRing;

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _hovering || widget.focused
              ? Colors.white.withValues(alpha: 0.08)
              : null,
        ),
        child: FocusRing(
          focused: widget.focused,
          circular: widget.circularRing,
          child: IconButton(
            key: widget.buttonKey,
            icon: Icon(widget.icon, size: 26, color: widget.color),
            onPressed: widget.onPressed,
          ),
        ),
      ),
    );
  }
}

/// Grey vertical-bar + letters state chip appended to the big line.
class _StateChip extends StatelessWidget {
  const _StateChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 2, height: 34, color: AppColors.text),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 16,
            color: AppColors.text,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

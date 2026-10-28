import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planner_engine/planner_engine.dart';

import 'app_controller.dart';
import 'editor_controller.dart';
import 'editor_screen.dart';
import 'format.dart';
import 'theme.dart';

/// The main board screen: header, state-driven dial with the readout in its
/// center, the control row (interval list, reset, skip), and the
/// next-interval caption below — or the pulsing tap-to-continue affordance
/// while the run holds at a zeroed manually-complete instance.
///
/// Interaction is a single context action dispatched by snapshot state —
/// start / pause / resume / skip — reachable both by tapping the dial and
/// by pressing Space. Right-clicking the dial opens the (P4.1) editor.
///
/// No menu/gear buttons in the header: multi-board switching and settings
/// are out of v1 scope.
class BoardScreen extends StatelessWidget {
  const BoardScreen(this.controller, {super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Focus(
        // Space performs the same context action as a dial tap.
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => _buildBoard(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(BuildContext context) {
    final snapshot = controller.snapshot;
    final timerColor = _hexColor(controller.timer.color);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          controller.board.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.lightBlue,
          ),
        ),
        const SizedBox(height: 16),
        _dial(context, snapshot, timerColor),
        const SizedBox(height: 12),
        _controlRow(context, snapshot),
        const SizedBox(height: 12),
        if (snapshot.state == SessionState.awaitingAdvance)
          _tapToContinue()
        else
          _caption(snapshot),
        const SizedBox(height: 24),
      ],
    );
  }

  /// The dial: tick ring painted around the state-driven readout.
  Widget _dial(BuildContext context, TimerSnapshot snapshot, Color timerColor) {
    return GestureDetector(
      key: const Key('dial'),
      onTapDown: (_) => dispatchContextAction(),
      onSecondaryTapDown: (_) async {
        // Right-click opens the editor over a freshly loaded tree; Done in
        // the editor commits and reloads the board's session (onDone).
        final tree = await controller.store.loadTree(controller.timer.id);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EditorScreen(
              controller: EditorController(
                store: controller.store,
                timer: controller.timer,
                initialTree: tree,
              ),
              onDone: () => controller.reload(),
            ),
          ),
        );
      },
      child: SizedBox(
        width: 340,
        height: 340,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DialPainter(
                  elapsed: _elapsedFraction(snapshot),
                  timerColor: timerColor,
                ),
              ),
            ),
            // Scale the readout down to fit inside the ring at any window
            // size.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _readout(snapshot, timerColor),
            ),
          ],
        ),
      ),
    );
  }

  /// Fraction (0..1) of the current instance already elapsed — drives the
  /// tick ring. Zero at notStarted; a held-at-zero awaitingAdvance instance
  /// is fully elapsed.
  double _elapsedFraction(TimerSnapshot snapshot) {
    if (snapshot.state == SessionState.notStarted ||
        snapshot.ordinal == null ||
        snapshot.remaining == null) {
      return 0;
    }
    final totalMs =
        controller.instances[snapshot.ordinal!].durationSeconds * 1000;
    if (totalMs <= 0) return 0;
    final elapsed = 1 - snapshot.remaining!.inMilliseconds / totalMs;
    return elapsed.clamp(0.0, 1.0).toDouble();
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
        return _RunReadout(snapshot: snapshot);
    }
  }

  /// `≫ next interval` caption — shown iff an instance follows the cursor
  /// (at notStarted the first instance is "next").
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
          '${formatDuration(Duration(seconds: next.durationSeconds))}',
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 17,
            color: AppColors.lightBlue,
          ),
        ),
      ],
    );
  }

  /// Control row between dial and caption: open the interval list, reset
  /// (with confirmation), and skip. Skip is disabled ONLY at notStarted —
  /// there is nothing to skip before a run begins; every other state
  /// (running, paused, awaitingAdvance) skips.
  Widget _controlRow(BuildContext context, TimerSnapshot snapshot) {
    final canSkip = snapshot.state != SessionState.notStarted;
    return Row(
      key: const Key('control-row'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _control(
          key: const Key('btn-list'),
          icon: Icons.menu,
          tooltip: 'Intervals',
          onPressed: () => _showListOverlay(context),
        ),
        const SizedBox(width: 8),
        _control(
          key: const Key('btn-reset'),
          icon: Icons.close_outlined,
          tooltip: 'Reset',
          onPressed: () => _showResetDialog(context),
        ),
        const SizedBox(width: 8),
        _control(
          key: const Key('btn-skip'),
          icon: Icons.chevron_right,
          tooltip: 'Skip',
          onPressed: canSkip ? () => controller.skipNext() : null,
        ),
      ],
    );
  }

  /// One rounded-card [IconButton] of the control row.
  Widget _control({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => Container(
    padding: const EdgeInsets.all(6),
    decoration: const BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    child: IconButton(
      key: key,
      icon: Icon(icon, size: 26, color: AppColors.blue),
      tooltip: tooltip,
      onPressed: onPressed,
    ),
  );

  /// The interval-list overlay: every instance in order, the current one
  /// highlighted, a tap jumps the cursor there AND closes the overlay.
  void _showListOverlay(BuildContext context) {
    final instances = controller.instances;
    final current = controller.snapshot.ordinal;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const Key('list-overlay'),
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: SizedBox(
          height: 420,
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text(
                  'Intervals',
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: instances.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    color: AppColors.outline,
                  ),
                  itemBuilder: (context, index) {
                    final instance = instances[index];
                    final isCurrent = index == current;
                    // Odd rows get a subtle tint; the current row wins it
                    // with a blue highlight.
                    final background = isCurrent
                        ? AppColors.blue.withValues(alpha: 0.25)
                        : index.isOdd
                            ? Colors.white.withValues(alpha: 0.03)
                            : null;
                    return InkWell(
                      onTap: () {
                        controller.jumpTo(index);
                        Navigator.of(dialogContext).pop();
                      },
                      child: Container(
                        key: Key('list-row-$index'),
                        color: background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatInstanceLabel(index, instance.name),
                                style: TextStyle(
                                  fontFamily: AppFonts.ui,
                                  fontSize: 15,
                                  color: isCurrent
                                      ? AppColors.lightBlue
                                      : AppColors.text,
                                ),
                              ),
                            ),
                            Text(
                              formatDuration(
                                Duration(seconds: instance.durationSeconds),
                              ),
                              style: const TextStyle(
                                fontFamily: AppFonts.digits,
                                fontSize: 15,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reset confirmation: nothing happens without an explicit confirm —
  /// Cancel and the barrier tap just dismiss.
  void _showResetDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Reset timer?'),
        content: const Text(
          'The current run will end and the timer returns to not started.',
        ),
        actions: [
          TextButton(
            key: const Key('dialog-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('dialog-confirm'),
            onPressed: () {
              controller.reset();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  /// Awaiting-advance affordance: REPLACES the caption while the run holds
  /// at a zeroed manually-complete instance — tap to advance (which resets
  /// to fresh notStarted at the end of the list).
  Widget _tapToContinue() {
    return GestureDetector(
      key: const Key('tap-to-continue'),
      onTapDown: (_) => controller.skipNext(),
      child: _Pulse(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.double_arrow,
              size: 18,
              color: AppColors.lightBlue,
            ),
            const SizedBox(width: 4),
            const Text(
              'tap to continue',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 17,
                color: AppColors.lightBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The one context action, dispatched by snapshot state — the dial tap
  /// and Space both land here.
  void dispatchContextAction() {
    switch (controller.snapshot.state) {
      case SessionState.notStarted:
        controller.start();
      case SessionState.running:
        controller.pause();
      case SessionState.paused:
        controller.resume();
      case SessionState.awaitingAdvance:
        controller.skipNext();
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Space down = the context action; key-ups and key-repeat events (which
    // arrive as [KeyRepeatEvent], not [KeyDownEvent]) are ignored so a held
    // Space doesn't flap pause/resume.
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      dispatchContextAction();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

/// `#rrggbb` hex (v1 preset swatches) → opaque [Color].
Color _hexColor(String hex) =>
    Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

/// Tick ring painter (cribbed from the P0.2 mock's `_DialPainter`): thin
/// outer ring in the timer color plus 60 round-cap ticks — the elapsed arc
/// dimmed, the remaining arc in the timer color.
class _DialPainter extends CustomPainter {
  const _DialPainter({required this.elapsed, required this.timerColor});

  /// Elapsed fraction (0..1) of the current instance.
  final double elapsed;

  final Color timerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // Outer ring.
    canvas.drawCircle(
      center,
      radius - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = timerColor,
    );

    // Tick ring.
    final tickInner = radius - 26;
    final tickOuter = radius - 11;
    final tickPaint = Paint()
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final angle = i * 2 * math.pi / 60 - math.pi / 2;
      final dir = Offset(math.cos(angle), math.sin(angle));
      tickPaint.color = (i / 60) < elapsed ? AppColors.dimmed : timerColor;
      canvas.drawLine(
        center + dir * tickInner,
        center + dir * tickOuter,
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed ||
      oldDelegate.timerColor != timerColor;
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

/// Blue vertical-bar + letters state chip appended to the big line.
class _StateChip extends StatelessWidget {
  const _StateChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 2, height: 34, color: AppColors.blue),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 16,
            color: AppColors.blue,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

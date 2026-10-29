import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
        _dial(context, snapshot, timerColor),
        const SizedBox(height: 12),
        _controlRow(context, snapshot),
        const SizedBox(height: 12),
        if (snapshot.state == SessionState.awaitingAdvance) _tapToContinue(),
        // The next-interval caption is gone (acceptance: it was MultiTimer's
        // advance button stand-in — the '>' control replaced it).
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
                  elapsed: _overallProgress(snapshot),
                  segments: _timelineSegments(),
                  timerColor: timerColor,
                ),
              ),
            ),
            // Scale the readout down to fit INSIDE the tick ring — the old
            // unconstrained FittedBox let the idle readout overlap the
            // ticks (acceptance: "time is still too large").
            SizedBox(
              width: 236,
              height: 236,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _readout(snapshot, timerColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The whole-timer timeline as color segments: fractional spans (0..1 of
  /// the total duration), one per flattened instance in its interval color
  /// (repeats expand to repeated segments). Empty timer → empty list (the
  /// painter falls back to the timer color).
  List<({double start, double end, Color color})> _timelineSegments() {
    final instances = controller.instances;
    final total = instances.fold<int>(0, (s, i) => s + i.durationSeconds);
    if (total <= 0) return const [];
    final segments = <({double start, double end, Color color})>[];
    var acc = 0;
    for (final inst in instances) {
      final start = acc / total;
      acc += inst.durationSeconds;
      segments.add((
        start: start,
        end: acc / total,
        color: _hexColor(inst.color),
      ));
    }
    return segments;
  }

  /// Fraction (0..1) of the WHOLE timer already elapsed — drives the tick
  /// ring's dim/bright boundary: completed instances plus the current
  /// instance's elapsed part. Zero at notStarted / after a reset; a
  /// held-at-zero awaitingAdvance instance counts as fully elapsed.
  double _overallProgress(TimerSnapshot snapshot) {
    if (snapshot.state == SessionState.notStarted ||
        snapshot.ordinal == null ||
        controller.instances.isEmpty) {
      return 0;
    }
    final instances = controller.instances;
    final totalMs =
        instances.fold<int>(0, (s, i) => s + i.durationSeconds) * 1000;
    if (totalMs <= 0) return 0;
    var doneMs = 0;
    for (var i = 0; i < snapshot.ordinal!; i++) {
      doneMs += instances[i].durationSeconds * 1000;
    }
    final curMs = instances[snapshot.ordinal!].durationSeconds * 1000;
    final remainingMs = snapshot.remaining?.inMilliseconds ?? curMs;
    doneMs += (curMs - remainingMs).clamp(0, curMs);
    return (doneMs / totalMs).clamp(0.0, 1.0).toDouble();
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
        _HoverIconButton(
          buttonKey: const Key('btn-list'),
          icon: Icons.menu,
          onPressed: () => _showListOverlay(context),
        ),
        const SizedBox(width: 8),
        _HoverIconButton(
          buttonKey: const Key('btn-reset'),
          icon: Icons.close_outlined,
          color: AppColors.danger, // destructive (greyscale-UI rule)
          onPressed: () => _showResetDialog(context),
        ),
        const SizedBox(width: 8),
        _HoverIconButton(
          buttonKey: const Key('btn-skip'),
          icon: Icons.chevron_right,
          onPressed: canSkip ? () => controller.skipNext() : null,
        ),
      ],
    );
  }

  /// The interval-list overlay: every instance in order, the current one
  /// highlighted, a tap jumps the cursor there AND closes the overlay.
  void _showListOverlay(BuildContext context) {
    final instances = controller.instances;
    final current = controller.snapshot.ordinal;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => blurredBackdrop(
        Dialog(
          key: const Key('list-overlay'),
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: AppColors.cardBorder),
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
                    // with a grey highlight (greyscale-UI rule).
                    final background = isCurrent
                        ? AppColors.text.withValues(alpha: 0.25)
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
                                      ? AppColors.text
                                      : AppColors.dimmed,
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
      ),
    );
  }

  /// Reset confirmation: nothing happens without an explicit confirm —
  /// Cancel and the barrier tap just dismiss.
  void _showResetDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => blurredBackdrop(
        AlertDialog(
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: AppColors.cardBorder),
          ),
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
              child: const Text(
                'Reset',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        ),
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

/// Tick ring painter: thin outer ring in the TIMER color plus 60
/// round-cap ticks spanning the WHOLE timer — each tick takes the color of
/// the timeline segment (interval instance) it falls into, so the ring is
/// a color map of the entire run (short intervals in long timers may land
/// on zero ticks — accepted trade-off of the fixed 60-tick resolution).
/// Ticks at or before the progress boundary are elapsed: drawn at the
/// universal semi-transparent alpha (theme card) and 66% brightness —
/// dimmed but still in their interval color, so the dim/bright edge marks
/// "now" and the colors map the whole run.
class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.elapsed,
    required this.segments,
    required this.timerColor,
  });

  /// Elapsed fraction (0..1) of the whole timer.
  final double elapsed;

  /// Timeline segments: fractional spans of the total + interval color.
  final List<({double start, double end, Color color})> segments;

  /// Ring color — also the tick fallback when there are no segments.
  final Color timerColor;

  /// Alpha shared with the app's semi-transparent backgrounds (AppColors
  /// card's alpha — follows it when halved.
  static final double _dimAlpha = AppColors.card.a;

  /// Elapsed-tick brightness relative to the interval color.
  static const double _dimBrightness = 0.66;

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

    // Tick ring: whole-timer color map; elapsed ticks dimmed.
    final tickInner = radius - 26;
    final tickOuter = radius - 11;
    final tickPaint = Paint()
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final frac = (i + 0.5) / 60;
      final angle = i * 2 * math.pi / 60 - math.pi / 2;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final color = _colorAt(frac);
      tickPaint.color = frac < elapsed ? _dim(color) : color;
      canvas.drawLine(
        center + dir * tickInner,
        center + dir * tickOuter,
        tickPaint,
      );
    }
  }

  /// The interval color at timeline fraction [frac] — tick midpoint lookup,
  /// no half-ticks at segment boundaries.
  Color _colorAt(double frac) {
    for (final s in segments) {
      if (frac >= s.start && frac < s.end) return s.color;
    }
    return segments.isEmpty ? timerColor : segments.last.color;
  }

  /// Elapsed-tick color: 66% brightness + the shared semi-transparent
  /// alpha (over the transparent window this blends with the desktop).
  Color _dim(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * _dimBrightness).clamp(0.0, 1.0))
        .toColor()
        .withValues(alpha: _dimAlpha);
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed ||
      oldDelegate.timerColor != timerColor ||
      !listEquals(oldDelegate.segments, segments);
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
  });

  /// Lives on the INNER IconButton (tests address the button by key).
  final Key buttonKey;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

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
          color: _hovering ? Colors.white.withValues(alpha: 0.08) : null,
        ),
        child: IconButton(
          key: widget.buttonKey,
          icon: Icon(widget.icon, size: 26, color: widget.color),
          onPressed: widget.onPressed,
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

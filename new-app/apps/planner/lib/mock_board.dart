import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Static mock of the MultiTimer board screen (UI-REFERENCE item 1) plus an
/// interval-chip list with a group bracket (editor reference styling).
///
/// P0.2 risk-burner: hardcoded values, no behavior except hover. Exists to
/// judge fonts/theme/transparency aesthetics — the real board lands in P3.x.
class MockBoardPage extends StatelessWidget {
  const MockBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _TopBar(),
                const SizedBox(height: 24),
                const _Dial(),
                const SizedBox(height: 20),
                const _ControlRow(),
                const SizedBox(height: 12),
                const _NextCaption('1. break - 7m 30s'),
                const SizedBox(height: 24),
                const _ChipListCard(),
                const SizedBox(height: 16),
                const _PageDots(count: 3, active: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hamburger | board name | gear — circular outline buttons at the edges.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundOutlineButton(
          icon: Icons.menu,
          tooltip: 'Boards',
          onPressed: () {},
        ),
        const Expanded(
          child: Text(
            'tmp',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.lightBlue,
            ),
          ),
        ),
        _RoundOutlineButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onPressed: () {},
        ),
      ],
    );
  }
}

class _RoundOutlineButton extends StatelessWidget {
  const _RoundOutlineButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: const BorderSide(color: AppColors.outline, width: 1.5),
          padding: const EdgeInsets.all(14),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 22, color: AppColors.lightBlue),
      ),
    );
  }
}

/// Dial: thick outer ring + 60-tick ring with hardcoded purple accents.
class _Dial extends StatelessWidget {
  const _Dial();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      height: 340,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _DialPainter())),
          // Scale the readout down to fit inside the ring at any window size.
          const FittedBox(fit: BoxFit.scaleDown, child: _DialReadout()),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter();

  // Tick indices drawn violet, mimicking the reference screenshot's scattered
  // purple clusters in the blue tick ring.
  static const Set<int> _violetTicks = {
    2,
    3,
    11,
    17,
    18,
    26,
    33,
    34,
    35,
    41,
    49,
    50,
    57,
  };

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
        ..color = AppColors.blue,
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
      tickPaint.color = _violetTicks.contains(i)
          ? AppColors.violet
          : AppColors.blue;
      canvas.drawLine(
        center + dir * tickInner,
        center + dir * tickOuter,
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) => false;
}

/// `03H : 00M` big with a small seconds subscript, all MonoLisa.
class _DialReadout extends StatelessWidget {
  const _DialReadout();

  static const _bigStyle = TextStyle(
    fontFamily: AppFonts.digits,
    fontWeight: FontWeight.w500,
    fontSize: 72,
    height: 1.0,
    color: AppColors.blue,
  );

  static const _unitStyle = TextStyle(
    fontFamily: AppFonts.digits,
    fontWeight: FontWeight.w500,
    fontSize: 24,
    height: 1.0,
    color: AppColors.blue,
  );

  static const _secondsStyle = TextStyle(
    fontFamily: AppFonts.digits,
    fontWeight: FontWeight.w500,
    fontSize: 20,
    height: 1.0,
    color: AppColors.blue,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('03', style: _bigStyle),
        const SizedBox(width: 3),
        const Text('H', style: _unitStyle),
        const SizedBox(width: 8),
        const Text(':', style: _bigStyle),
        const SizedBox(width: 8),
        const Text('00', style: _bigStyle),
        const SizedBox(width: 3),
        const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('M', style: _unitStyle),
            SizedBox(height: 2),
            Text('00', style: _secondsStyle),
          ],
        ),
      ],
    );
  }
}

/// Six-icon control row; pause disabled (timer not started).
class _ControlRow extends StatelessWidget {
  const _ControlRow();

  @override
  Widget build(BuildContext context) {
    Widget button(
      String key,
      IconData icon,
      String tooltip, {
      bool enabled = true,
    }) {
      return IconButton(
        key: Key(key),
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: enabled ? () {} : null,
        padding: const EdgeInsets.symmetric(horizontal: 14),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button('control-play', Icons.play_arrow_outlined, 'Start'),
        button('control-restart', Icons.history_outlined, 'Restart'),
        button('control-pause', Icons.pause_outlined, 'Pause', enabled: false),
        button('control-list', Icons.format_list_bulleted, 'Intervals'),
        button('control-close', Icons.close_outlined, 'Close'),
        button('control-lock', Icons.lock_open_outlined, 'Lock'),
      ],
    );
  }
}

/// `≫ next interval` caption row.
class _NextCaption extends StatelessWidget {
  const _NextCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.double_arrow, size: 18, color: AppColors.lightBlue),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 17,
            color: AppColors.lightBlue,
          ),
        ),
      ],
    );
  }
}

/// Interval chips with a group bracket, inside a dark card (editor styling).
class _ChipListCard extends StatelessWidget {
  const _ChipListCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IntervalChip(
            key: Key('chip-Run'),
            label: 'Run',
            duration: '50m',
            color: AppColors.blue,
          ),
          SizedBox(height: 10),
          _GroupBracket(
            key: Key('group-bracket'),
            count: '8',
            children: [
              _IntervalChip(
                key: Key('chip-break'),
                label: 'break',
                duration: '7m 30s',
                color: AppColors.violet,
                selected: true,
              ),
              SizedBox(height: 8),
              _IntervalChip(
                key: Key('chip-Cards'),
                label: 'Cards',
                duration: '15m',
                color: AppColors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One interval chip: selection radio | label | right-aligned duration.
class _IntervalChip extends StatelessWidget {
  const _IntervalChip({
    super.key,
    required this.label,
    required this.duration,
    required this.color,
    this.selected = false,
  });

  final String label;
  final String duration;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Row(
        children: [
          // Selection radio.
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outline, width: 1.4),
              color: selected ? color.withValues(alpha: 0.35) : null,
            ),
            child: selected
                ? Icon(Icons.check, size: 14, color: AppColors.text)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 15,
                color: AppColors.text,
              ),
            ),
          ),
          Text(
            duration,
            style: const TextStyle(
              fontFamily: AppFonts.digits,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Group bracket column: repeat-count badge on top, rounded `[` down the side.
class _GroupBracket extends StatelessWidget {
  const _GroupBracket({super.key, required this.count, required this.children});

  final String count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight: the bracket must stretch to the chips' natural height
    // (raw stretch gets infinite constraints inside the scroll view).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Stack(
              children: [
                // Bracket glyph, starting below the count badge.
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: CustomPaint(painter: _BracketPainter()),
                  ),
                ),
                // Repeat-count badge.
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    key: const Key('group-count'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.outline, width: 1.2),
                      color: AppColors.card,
                    ),
                    child: Text(
                      count,
                      style: const TextStyle(
                        fontFamily: AppFonts.digits,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const r = 7.0;
    final x = size.width - 2;
    final path = Path()
      ..moveTo(2, r)
      ..lineTo(2, r) // top stub start (left end)
      ..lineTo(x - r, 2)
      ..quadraticBezierTo(x, 2, x, 2 + r)
      ..lineTo(x, size.height - 2 - r)
      ..quadraticBezierTo(x, size.height - 2, x - r, size.height - 2)
      ..lineTo(2, size.height - 2);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.outline,
    );
  }

  @override
  bool shouldRepaint(covariant _BracketPainter oldDelegate) => false;
}

/// Row of page dots, `active` filled.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Container(
            key: Key('page-dot-$i'),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == active ? AppColors.lightBlue : null,
              border: i == active
                  ? null
                  : Border.all(color: AppColors.outline, width: 1.2),
            ),
          ),
        ],
      ],
    );
  }
}

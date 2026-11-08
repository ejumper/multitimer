import 'package:flutter/material.dart';
import 'package:planner_engine/planner_engine.dart';

import 'format.dart';
import 'keyboard_nav.dart';
import 'theme.dart';

/// Shared interval-row rendering (CONVENTIONS §7, P2.1) — extracted from
/// the timer editor so the editor (authoring) and the board's list view
/// (playback) speak ONE row vocabulary: the chip card (title top-left,
/// shape top-right, alert label bottom-left), the circular slot at the
/// far left (the editor's selection circle / the board's completion
/// checkbox), the group bracket bar with its repeat counter, and the
/// left→right progress fill.

/// `#rrggbb` hex (v1 preset swatches) → opaque [Color].
Color hexColor(String hex) =>
    Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

/// The chip's right-hand shape (P1.5): the trigger time when dated
/// (`15:30`), else the duration when present, else `open` for an Open
/// interval — the three v2 shapes (dated / timed / open) at a glance.
String rowShape(IntervalDef def) {
  final trigger = def.triggerTimeSeconds;
  if (trigger != null) return formatWallTime(trigger);
  final duration = def.durationSeconds;
  if (duration != null) return formatDuration(Duration(seconds: duration));
  return 'open';
}

/// The row's left→right background fill: a colored band covering the
/// leftmost [fraction] of the row's track (0 = empty, 1 = full). The card
/// hosts it behind its content and clips it to the rounded rect; the
/// editor renders cards without one ([fillFraction] null).
class RowFill extends StatelessWidget {
  const RowFill({super.key, required this.fraction, required this.color});

  /// Elapsed fraction (0..1) of the row's progress.
  final double fraction;

  /// Band color — the interval tint for chip rows, the outline token for
  /// group rows.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    if (f <= 0) return const SizedBox.shrink();
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: f,
      heightFactor: 1.0,
      child: ColoredBox(color: color),
    );
  }
}

/// One interval card: title top-left, [shape] top-right (the board's live
/// duration slot — countdown / wall time / `open` / `wait` — the editor's
/// authored shape), an optional small [badge] after it, and the alert
/// label bottom-left — over the interval-color tinted, bordered
/// background.
class IntervalChipCard extends StatelessWidget {
  const IntervalChipCard({
    super.key,
    required this.def,
    required this.shape,
    this.shapeKey,
    this.badge,
    this.fillFraction,
    this.fillColor,
    this.fillKey,
    this.bordered = true,
  });

  final IntervalDef def;

  /// The right-hand slot's text (see [rowShape] for the authored form).
  final String shape;

  /// Key for the shape text (the board addresses the live slot).
  final Key? shapeKey;

  /// Small trailing badge on the top row (the board's `late`).
  final String? badge;

  /// Left→right progress fill (board rows only; null = none).
  final double? fillFraction;
  final Color? fillColor;
  final Key? fillKey;

  /// False at a hold (awaitingAdvance): the board draws the pulsing
  /// border instead of the static one.
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final alert = def.endAlertSoundFile;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                def.name ?? 'Interval',
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              shape,
              key: shapeKey,
              style: const TextStyle(
                fontFamily: AppFonts.digits,
                fontSize: 14,
                color: AppColors.text,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Text(
                badge!,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 11,
                  color: AppColors.dimmed,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              alert == null
                  ? Icons.volume_off_outlined
                  : Icons.volume_up_outlined,
              size: 12,
              color: AppColors.dimmed,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                alert ?? 'No end alert',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 12,
                  color: AppColors.dimmed,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      clipBehavior: Clip.antiAlias, // the fill must not square the corners
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(AppDecorations.rectRadius),
        ),
        border: bordered
            ? Border.all(
                color: hexColor(def.color),
                width: AppDecorations.borderWidth,
              )
            : null,
        // Interval-color tinted background @ the shared semi-transparent
        // alpha (acceptance: "Color intervals background in the editor").
        color: hexColor(def.color).withValues(alpha: AppColors.card.a),
      ),
      child: fillFraction == null
          ? content
          : Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: RowFill(
                    key: fillKey,
                    fraction: fillFraction!,
                    color: fillColor ?? hexColor(def.color),
                  ),
                ),
                content,
              ],
            ),
    );
  }
}

/// The 20px circular slot at the far left of every row: the editor's
/// selection circle and the board's completion checkbox share this visual
/// — checked shows the tinted fill + check. [onTap] null = decorative
/// (the group slot has no single-item toggle).
class RowCircle extends StatelessWidget {
  const RowCircle({
    super.key,
    required this.checked,
    this.focused = false,
    this.onTap,
  });

  final bool checked;
  final bool focused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      focused: focused,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.outline,
              width: AppDecorations.borderWidth,
            ),
            color: checked ? AppColors.text.withValues(alpha: 0.35) : null,
          ),
          child: checked
              ? const Icon(Icons.check, size: 14, color: AppColors.text)
              : null,
        ),
      ),
    );
  }
}

/// The group's bracket bar: a filled capsule down the group's left edge
/// with [repeatLabel] centered over its middle — the editor's repeat
/// stepper target (total passes), the board's repeats-LEFT counter.
class GroupBracketBar extends StatelessWidget {
  const GroupBracketBar({
    super.key,
    required this.repeatLabel,
    this.repeatKey,
    this.focused = false,
    this.onTap,
  });

  /// The count text (`'3'` in the editor, `'2'` … `'0'` on the board).
  final String repeatLabel;

  /// Key for the centered count text (tests address it directly).
  final Key? repeatKey;

  /// Keyboard-focus ring + tap target (the editor's stepper).
  final bool focused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: FocusRing(
        focused: focused,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            children: [
              // The group bar: filled capsule (editor: repeat stepper
              // target; board: the group's progress anchor).
              Positioned.fill(child: CustomPaint(painter: GroupBarPainter())),
              // Repeat count: centered BOTH ways, plain text.
              Positioned.fill(
                child: Center(
                  key: repeatKey,
                  child: Text(
                    repeatLabel,
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
      ),
    );
  }
}

/// The group bar (MultiTimer-style, IMG_6229/6230): a filled CAPSULE down
/// the group's left edge — closed rounded rectangle (it HAS a left side),
/// filled with the outline's color at the app's semi-transparent opacity,
/// stroked with the outline color.
class GroupBarPainter extends CustomPainter {
  const GroupBarPainter();

  /// Outline color @ the shared semi-transparent alpha (theme card,
  /// halved again per acceptance).
  static final Color _fill = AppColors.outline.withValues(
    alpha: AppColors.card.a,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bar = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width / 2), // capsule ends
    );
    canvas.drawRRect(bar, Paint()..color = _fill);
    canvas.drawRRect(
      bar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppDecorations.borderWidth
        ..color = AppColors.outline,
    );
  }

  @override
  bool shouldRepaint(covariant GroupBarPainter oldDelegate) => false;
}

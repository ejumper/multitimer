import 'package:flutter/material.dart';

import 'keyboard_nav.dart';
import 'theme.dart';

/// The app's shared bottom bar (v2 outline, "Bottom Bar Menu"; P3.1): a
/// pill-shaped, semi-transparent background with an outline and the
/// buttons evenly spaced across it. Every page renders ITS OWN bar from
/// this widget — the button set is page-contextual (the outline's
/// per-page bars): the board hosts the main bar, the Library the task-list
/// bar, a plan board the home/back bar.
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.buttons});

  /// The bar's buttons, left to right (usually [BarButton]s).
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        // Semi-transparent card fill over the compositor blur + the shared
        // hairline outline — the outline's "pill shaped semitransparent
        // background with an outline".
        color: AppColors.card,
        border: Border.all(
          color: AppColors.outline,
          width: AppDecorations.borderWidth,
        ),
        // Radius ≥ half the height → the painter clamps it into a pill.
        borderRadius: const BorderRadius.all(Radius.circular(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            buttons[i],
          ],
        ],
      ),
    );
  }
}

/// Which bar a [BoardScreen] renders (P3.1): the board is both the home
/// screen and the plan board a Library plan opens into.
enum BoardBar {
  /// Home: Settings · Calendar · Library · New Event — each with its
  /// P5.3 quick action where the outline defines one (right-click
  /// Calendar = the non-default view, right-click Library =
  /// save-to-folder; Settings and New Event have none).
  main,

  /// A plan board or day board — the outline's merged task/temp-board
  /// bar (P5.3), left to right: home (today's day board — P4.3) · back
  /// (pop one level) · new item (the interval editor in CREATE mode) ·
  /// delete mode (tap a row → confirmed delete) · checklist toggle
  /// (P3.3) · show/hide completed (P3.3) · defaults (the default-rules
  /// menu, v2 P3.4).
  plan,
}

/// The bar's icon button: NO resting background — a circular HOVER
/// highlight appears on hover and is "just a touch bigger" than the icon
/// (the control row's button, shared since P3.1). The hover circle shows
/// even when [onPressed] is null (the present-but-disabled bar buttons of
/// the early P3 chunks), and there is no tooltip text.
class BarButton extends StatefulWidget {
  const BarButton({
    super.key,
    required this.buttonKey,
    required this.icon,
    required this.onPressed,
    this.onSecondaryTap,
    this.color = AppColors.text,
    this.focused = false,
    this.circularRing = true,
  });

  /// Lives on the INNER IconButton (tests address the button by key).
  final Key buttonKey;
  final IconData icon;
  final VoidCallback? onPressed;

  /// P5.3 — the button's QUICK ACTION (the outline's right-click /
  /// long-press vocabulary): fires on the secondary tap over the same
  /// 46×46 target as the primary tap (the IconButton itself only ever
  /// answers the primary). The main bar wires it — Calendar opens the
  /// non-default view, Library saves the open timer to a folder — while
  /// Settings and New Event keep it null (the outline defines no quick
  /// action for them).
  final VoidCallback? onSecondaryTap;

  final Color color;

  /// Keyboard-focus ring (acceptance keyboard navigation).
  final bool focused;

  /// Round buttons get a circular ring.
  final bool circularRing;

  @override
  State<BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<BarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final button = FocusRing(
      focused: widget.focused,
      circular: widget.circularRing,
      child: IconButton(
        key: widget.buttonKey,
        icon: Icon(widget.icon, size: 26, color: widget.color),
        onPressed: widget.onPressed,
      ),
    );
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
        // The quick action wraps the button content (secondary taps never
        // reach the IconButton); no wrapper when there is none to keep
        // the plain buttons' widget tree untouched.
        child: widget.onSecondaryTap == null
            ? button
            : GestureDetector(
                onSecondaryTapDown: (_) => widget.onSecondaryTap!(),
                child: button,
              ),
      ),
    );
  }
}

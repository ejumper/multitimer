import 'package:flutter/material.dart';

import 'bottom_bar.dart';

/// P5.3 — the hover-revealed window-edge chevron, ONE shared widget for
/// the pages that had it twice (the Calendar's week/month paging, P4.2,
/// and the day boards' day stepping, P4.3 — the two copies extracted
/// unchanged).
///
/// Behavior: the mouse ENTERING the 56px edge gutter reveals its
/// chevron ([AnimatedOpacity], 150ms fade), leaving hides it again —
/// the button sits at the gutter's VERTICAL CENTER in a strip laid out
/// BESIDE the reading column, so it never covers content. At rest the
/// chevron is invisible (opacity 0), exactly as before.
///
/// The three keys keep the pages' existing addressing: [gutterKey] on
/// the MouseRegion strip (`*-gutter-left/right`), [revealKey] on the
/// [AnimatedOpacity] (`*-prev/next-reveal`), [buttonKey] on the
/// chevron's inner IconButton (`*-prev/next`).
class EdgeChevron extends StatefulWidget {
  const EdgeChevron({
    super.key,
    required this.left,
    required this.gutterKey,
    required this.revealKey,
    required this.buttonKey,
    required this.onPressed,
  });

  /// Which window edge this gutter hugs: left = previous, right = next
  /// (also picks the chevron's direction).
  final bool left;

  /// The gutter strip's MouseRegion key.
  final Key gutterKey;

  /// The reveal animation's key (tests read its opacity).
  final Key revealKey;

  /// The chevron BarButton's inner IconButton key.
  final Key buttonKey;

  /// The chevron press: page/step one unit in this edge's direction.
  final VoidCallback onPressed;

  @override
  State<EdgeChevron> createState() => _EdgeChevronState();
}

class _EdgeChevronState extends State<EdgeChevron> {
  /// The reveal — set by the pointer entering/leaving this gutter only.
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      key: widget.gutterKey,
      onEnter: (_) => setState(() => _revealed = true),
      onExit: (_) => setState(() => _revealed = false),
      child: SizedBox(
        width: 56,
        child: Align(
          alignment: Alignment.center,
          child: AnimatedOpacity(
            key: widget.revealKey,
            opacity: _revealed ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: BarButton(
              buttonKey: widget.buttonKey,
              icon: widget.left ? Icons.chevron_left : Icons.chevron_right,
              onPressed: widget.onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:planner_engine/planner_engine.dart';

import 'editor_controller.dart';
import 'format.dart';
import 'interval_editor_placeholder.dart';
import 'theme.dart';

/// The interval-timer editor screen (P4.1) — UI-REFERENCE items 5/9/10:
/// header (✕ · "Interval timer" · Done pill), color swatch row, label field,
/// the "Intervals" toolbar (add / duplicate / delete / undo), and the chip
/// list with nested group brackets.
///
/// All edits go through the working-copy [controller]: ✕ reverts (the
/// controller is dropped without commit — nothing was written) and Done
/// commits the whole copy as one logged unit, then [onDone] fires (the board
/// passes `appController.reload`) before the route pops.
///
/// Drag-reorder rules (applied by [_acceptDrop], both via real drags and
/// the DragTarget callbacks):
///  - drop onto a GROUP row → append at the END of that group;
///  - drop onto a CHIP row  → the chip's own parent + the chip's index
///    (the dragged node lands at that chip's position);
///  - self-drops are ignored; the engine's [TreeOpException] (e.g. a group
///    dropped into its own subtree) aborts the move silently.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key, required this.controller, this.onDone});

  final EditorController controller;

  /// Invoked after a successful commit, just before the route pops.
  final VoidCallback? onDone;

  /// Preset accent swatches (D11), in reference order.
  static const List<String> _swatches = [
    '#ff00b1',
    '#4800ff',
    '#0055ff',
    '#00a8ff',
    '#00ad6b',
    '#b8ff00',
  ];

  /// Dark card background used by the row/toolbar containers.
  static const BoxDecoration _cardDecoration = BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context),
                    const SizedBox(height: 10),
                    _colorRow(),
                    const SizedBox(height: 10),
                    _LabelField(controller: controller),
                    const SizedBox(height: 16),
                    const Text(
                      'Intervals',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dimmed,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _toolbar(context),
                    const SizedBox(height: 10),
                    if (controller.tree.roots.isEmpty)
                      _emptyState(context)
                    else
                      _chipList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ✕ | centered title | Done pill. ✕ reverts and pops WITHOUT [onDone];
  /// Done commits, fires [onDone], then pops.
  Widget _header(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('editor-close'),
          icon: const Icon(Icons.close),
          color: AppColors.text,
          onPressed: () {
            controller.revert();
            Navigator.of(context).pop();
          },
        ),
        const Expanded(
          child: Text(
            'Interval timer',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        TextButton(
          key: const Key('editor-done'),
          style: TextButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: AppColors.text,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
          onPressed: () async {
            await controller.commit();
            onDone?.call();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text(
            'Done',
            style: TextStyle(fontFamily: AppFonts.ui, color: AppColors.text),
          ),
        ),
      ],
    );
  }

  /// The six preset swatches; the selected one shows a ring + center dot.
  Widget _colorRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final hex in _swatches) _swatch(hex)],
      ),
    );
  }

  Widget _swatch(String hex) {
    final selected = controller.color == hex;
    return GestureDetector(
      key: Key('swatch-$hex'),
      onTap: () => controller.setColor(hex),
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected ? Border.all(color: AppColors.text, width: 2) : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hexColor(hex),
          ),
          child: selected
              ? Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// Toolbar: add (→ interval editor, P4.3) · duplicate · delete · undo.
  /// Duplicate/delete need a selection; undo needs history — all mirrored
  /// live because the whole screen rebuilds on every notify.
  Widget _toolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: _cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            key: const Key('tool-add'),
            icon: const Icon(Icons.add),
            tooltip: 'Add',
            onPressed: () => _openIntervalEditor(context),
          ),
          IconButton(
            key: const Key('tool-duplicate'),
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Duplicate',
            onPressed: controller.hasSelection
                ? controller.duplicateSelection
                : null,
          ),
          IconButton(
            key: const Key('tool-delete'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: controller.hasSelection
                ? controller.deleteSelection
                : null,
          ),
          IconButton(
            key: const Key('tool-undo'),
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: controller.canUndo ? controller.undo : null,
          ),
        ],
      ),
    );
  }

  void _openIntervalEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IntervalEditorPlaceholderScreen(),
      ),
    );
  }

  /// The interval list: recursive over the working tree's roots.
  Widget _chipList() {
    return Column(
      key: const Key('chip-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _rows(controller.tree.roots, parentGroupId: null),
    );
  }

  /// One draggable + drop-target row per node, 8px between siblings.
  List<Widget> _rows(List<IntervalNode> nodes, {required String? parentGroupId}) {
    final rows = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      rows.add(_wrapNode(node, parentGroupId: parentGroupId, index: i));
      if (i < nodes.length - 1) {
        rows.add(const SizedBox(height: 8));
      }
    }
    return rows;
  }

  /// Wraps a chip/group row in the drag source AND the drop target; the
  /// target captures the node's position (parent + index) for [_acceptDrop].
  Widget _wrapNode(
    IntervalNode node, {
    required String? parentGroupId,
    required int index,
  }) {
    final row = switch (node) {
      DefNode(:final def) => _chipRow(def),
      GroupNode(:final group, :final children) => _groupRow(group, children),
    };
    return LongPressDraggable<String>(
      data: node.id,
      feedback: _dragFeedback(node),
      child: DragTarget<String>(
        key: Key('drop-${node.id}'),
        onAcceptWithDetails: (details) => _acceptDrop(
          details.data,
          target: node,
          parentGroupId: parentGroupId,
          index: index,
        ),
        builder: (context, _, _) => row,
      ),
    );
  }

  /// Drop handling per the class-doc rules; never crashes the editor.
  void _acceptDrop(
    String draggedId, {
    required IntervalNode target,
    required String? parentGroupId,
    required int index,
  }) {
    if (draggedId == target.id) return; // ignore self-drops
    try {
      if (target is GroupNode) {
        // Onto a group row → append at the END of that group.
        controller.moveNode(
          draggedId,
          newParentGroupId: target.id,
          newIndex: target.children.length,
        );
      } else {
        // Onto a chip row → that chip's parent + its index in that parent.
        controller.moveNode(
          draggedId,
          newParentGroupId: parentGroupId,
          newIndex: index,
        );
      }
    } on TreeOpException {
      // Invalid move (e.g. a group dropped into its own subtree) — the
      // engine rejects it; drop the event silently instead of crashing.
      return;
    }
  }

  /// One interval: selection circle | chip card (bordered, label left,
  /// duration right, alert subtitle below).
  Widget _chipRow(IntervalDef def) {
    return Row(
      key: Key('chip-${def.id}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _selectionCircle(def.id),
        const SizedBox(width: 10),
        Expanded(child: _chipCard(def)),
      ],
    );
  }

  Widget _chipCard(IntervalDef def) {
    final alert = def.endAlertSoundFile;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: _hexColor(def.color), width: 1.4),
      ),
      child: Column(
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
                formatDuration(Duration(seconds: def.durationSeconds)),
                style: const TextStyle(
                  fontFamily: AppFonts.digits,
                  fontSize: 14,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                alert == null ? Icons.volume_off_outlined : Icons.volume_up_outlined,
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
      ),
    );
  }

  /// One group: selection circle | 26px bracket column (repeat-count badge
  /// on top) | the children stacked inside, recursively — so nested groups
  /// stack their bracket columns further right (UI-REFERENCE items 9–10).
  Widget _groupRow(GroupDef group, List<IntervalNode> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _selectionCircle(group.id),
        const SizedBox(width: 10),
        Expanded(
          // IntrinsicHeight: the bracket must stretch to the children's
          // natural height (raw stretch gets unbounded constraints in here).
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Stack(
                    children: [
                      // Rounded-left bracket glyph, below the count badge.
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: CustomPaint(painter: _BracketPainter()),
                        ),
                      ),
                      // Repeat-count badge at the bracket's top-left.
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          key: Key('repeat-${group.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(5),
                            ),
                            border: Border.all(
                              color: AppColors.outline,
                              width: 1.2,
                            ),
                            color: AppColors.card,
                          ),
                          child: Text(
                            '${group.repeatCount}',
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
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _rows(children, parentGroupId: group.id),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 20px selection circle at the far left of every row; selected shows a
  /// blue-tinted fill + check.
  Widget _selectionCircle(String nodeId) {
    final selected = controller.selection.contains(nodeId);
    return GestureDetector(
      key: Key('select-$nodeId'),
      onTap: () => controller.toggleSelect(nodeId),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.outline, width: 1.4),
          color: selected ? AppColors.blue.withValues(alpha: 0.35) : null,
        ),
        child: selected
            ? const Icon(Icons.check, size: 14, color: AppColors.text)
            : null,
      ),
    );
  }

  /// The row preview shown while dragging.
  Widget _dragFeedback(IntervalNode node) {
    final label = switch (node) {
      DefNode(:final def) => def.name ?? 'Interval',
      GroupNode() => 'Group',
    };
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: AppColors.outline, width: 1.4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 14,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }

  /// Empty tree: the hint + the add affordance.
  Widget _emptyState(BuildContext context) {
    return Container(
      key: const Key('empty-state'),
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Text(
            'No intervals yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 15,
              color: AppColors.dimmed,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('empty-add'),
            onPressed: () => _openIntervalEditor(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 20),
                SizedBox(width: 4),
                Text('Add interval'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Label row: a stateful card field owning its [TextEditingController],
/// seeded once from the working-copy name; edits flow back via
/// [EditorController.rename].
class _LabelField extends StatefulWidget {
  const _LabelField({required this.controller});

  final EditorController controller;

  @override
  State<_LabelField> createState() => _LabelFieldState();
}

class _LabelFieldState extends State<_LabelField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.controller.name,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: EditorScreen._cardDecoration,
      child: TextField(
        key: const Key('label-field'),
        controller: _text,
        decoration: const InputDecoration(
          hintText: 'Add label',
          border: InputBorder.none,
        ),
        onChanged: widget.controller.rename,
      ),
    );
  }
}

/// Rounded `[` bracket glyph down the group's left edge (P0.2's
/// `_BracketPainter` style): outline stroke, ~7px corners.
class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const r = 7.0;
    final x = size.width - 2;
    final path = Path()
      ..moveTo(2, r)
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

/// `#rrggbb` hex (v1 preset swatches) → opaque [Color].
Color _hexColor(String hex) =>
    Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

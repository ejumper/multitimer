import 'package:flutter/material.dart';
import 'package:planner_engine/planner_engine.dart';

import 'adapters/ports.dart';
import 'editor_controller.dart';
import 'format.dart';
import 'interval_editor.dart';
import 'repeat_modal.dart';
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
/// Drag-reorder rules (slot-in model):
///  - press + move past touch slop starts a reorder — a clean tap still
///    opens the interval editor and the long-press delay is gone; the whole
///    row (chips and groups alike) lifts and follows the pointer VERTICALLY
///    (X stays locked to the column);
///  - the list reflows live and a slot marker opens at the prospective drop
///    position — between chips, inside a group (nested rows included), or at
///    either end of the list;
///  - slot mapping: a gap between two siblings inserts between them. A gap
///    at a group's edge is shared between the group, its parent levels and
///    the outside: the pointer's Y against the group rect picks the edge,
///    and the pointer's X picks the LEVEL — over a group's bracket column
///    = that group's level ("before/after the block"), over its content
///    column = one level deeper ("into the group"). The slot marker draws
///    at the chosen indent, so the target is always visible.
///  - one drag = one undo step; a completed drag clears the selection;
///  - invalid targets (a group into its own subtree) never become a slot
///    and the engine rejects anything else (TreeOpException → snap back).
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.controller,
    required this.soundsDir,
    required this.soundListing,
    required this.player,
    this.onDone,
  });

  final EditorController controller;

  /// Alert-sounds directory, rescan-on-demand listing, and preview player —
  /// handed straight to the interval editor's alert selector (P4.3).
  final String soundsDir;
  final List<String> Function() soundListing;
  final SoundPlayer player;

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
  State<EditorScreen> createState() => _EditorScreenState();
}

/// A measured leaf row during a drag.
class _RowInfo {
  const _RowInfo(this.id, this.parentId, this.index, this.rect);

  final String id;
  final String? parentId;
  final int index;
  final Rect rect;
}

/// A drop slot: "insert before the node at [index] among the children of
/// [parentId] (null = root)".
class _Slot {
  const _Slot(this.parentId, this.index);

  final String? parentId;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is _Slot && other.parentId == parentId && other.index == index;

  @override
  int get hashCode => Object.hash(parentId, index);
}

/// Snapshot of the in-flight drag.
class _Drag {
  const _Drag(this.node, this.rect, this.grabDy);

  final IntervalNode node;
  final Rect rect;
  final double grabDy;
}

class _EditorScreenState extends State<EditorScreen> {
  EditorController get controller => widget.controller;

  // ── drag-reorder state ────────────────────────────────────────────────

  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  _Drag? _drag;
  Offset? _pendingGrab;
  Offset _pointer = Offset.zero;
  _Slot? _target;
  OverlayEntry? _float;

  GlobalKey _keyFor(String id) => _rowKeys.putIfAbsent(id, GlobalKey.new);

  @override
  void dispose() {
    _float?.remove();
    _float = null;
    super.dispose();
  }

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
            widget.onDone?.call();
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
      decoration: EditorScreen._cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [for (final hex in EditorScreen._swatches) _swatch(hex)],
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

  /// Toolbar: add (→ interval editor, P4.3) · duplicate · delete · undo ·
  /// group · ungroup. Duplicate/delete need a selection; undo needs
  /// history; group needs a contiguous sibling run; ungroup a selected
  /// root-level group — all mirrored live because the whole screen
  /// rebuilds on every notify.
  Widget _toolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: EditorScreen._cardDecoration,
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
          IconButton(
            key: const Key('tool-group'),
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Group',
            // Grouping needs a run of CONTIGUOUS siblings — stricter than
            // the engine's grouped op, which tolerates non-adjacent
            // siblings by pulling them together (UI choice).
            onPressed: controller.canGroup
                ? () => _groupTapped(context)
                : null,
          ),
          IconButton(
            key: const Key('tool-ungroup'),
            icon: const Icon(Icons.layers_clear),
            tooltip: 'Ungroup',
            onPressed: controller.canUngroup
                ? controller.ungroupSelection
                : null,
          ),
        ],
      ),
    );
  }

  /// Opens the interval editor (P4.3): CREATE when [defId] is null (the
  /// "+" toolbar button and the empty-state affordance), EDIT for the
  /// tapped chip's def.
  void _openIntervalEditor(BuildContext context, {String? defId}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IntervalEditorScreen(
          controller: controller,
          defId: defId,
          soundsDir: widget.soundsDir,
          soundListing: widget.soundListing,
          player: widget.player,
        ),
      ),
    );
  }

  /// Toolbar "Group": wrap the topmost selection in a fresh group (repeat
  /// 1), then open the repeat stepper for it (UI-REFERENCE item 8) and
  /// apply the confirmed pass count.
  Future<void> _groupTapped(BuildContext context) async {
    final groupId = controller.groupSelection();
    if (!context.mounted) return;
    final repeat = await showRepeatModal(context, initial: 1);
    if (repeat != null && context.mounted) {
      controller.setGroupRepeat(groupId, repeat);
    }
  }

  /// Bracket-bar tap → reopen the stepper for that group, seeded with its
  /// current count. Documented MultiTimer-mirroring decision: ONLY
  /// root-level groups respond — an inner group's bracket does NOTHING
  /// (parent != null); inner groups become reachable only after the group
  /// holding them is ungrouped.
  Future<void> _bracketTapped(BuildContext context, GroupDef group) async {
    if (controller.tree.parentOf(group.id) != null) return; // inner: no-op
    controller.selectOnly(group.id);
    final repeat = await showRepeatModal(context, initial: group.repeatCount);
    if (repeat != null && context.mounted) {
      controller.setGroupRepeat(group.id, repeat);
    }
  }

  /// The interval list: recursive over the working tree's roots.
  Widget _chipList() {
    return Column(
      key: const Key('chip-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _rows(controller.tree.roots, parentGroupId: null),
    );
  }

  /// One row per node (8px between entries), with the drag slot marker
  /// injected at [_target] and the dragged row(s) dropped from the layout
  /// (the gap it leaves closes; the slot marker is the visible hole).
  List<Widget> _rows(
    List<IntervalNode> nodes, {
    required String? parentGroupId,
    bool keyed = true,
  }) {
    final entries = <Widget>[];
    for (var i = 0; i <= nodes.length; i++) {
      final target = _target;
      if (target != null &&
          target.parentId == parentGroupId &&
          target.index == i) {
        entries.add(_slotGap());
      }
      if (i < nodes.length) {
        final node = nodes[i];
        // Always Offstage-wrapped (STABLE shape): unmounting the dragged
        // row — or changing the widget type at its slot — would recreate the
        // detector's element and dispose its drag recognizer mid-gesture,
        // so end/cancel would never fire. Only the dragged ROOT is hidden
        // (its subtree renders normally — it is inside the root's offstage
        // anyway, and hiding descendants would collapse the group's
        // IntrinsicHeight measurement to zero).
        entries.add(
          Offstage(
            // The KEY lives on the Offstage (the Column's direct child):
            // when the slot gap inserts into this same column, unkeyed
            // children match positionally and the dragged row's detector
            // would be recreated — disposing the tracking recognizer
            // mid-gesture (end/cancel never fire). Keyed children survive
            // the churn with their elements intact.
            key: Key('row-${node.id}'),
            offstage: _drag?.node.id == node.id,
            child: _wrapNode(
              node,
              parentGroupId: parentGroupId,
              index: i,
              keyed: keyed,
            ),
          ),
        );
      }
    }
    return [
      for (var i = 0; i < entries.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        entries[i],
      ],
    ];
  }

  /// Wraps a chip/group row in the drag recognizer. A clean tap falls
  /// through to the row's own tap targets (chip body → interval editor,
  /// selection circle → select, bracket → repeat stepper); a press + move
  /// past touch slop lifts the row. Inner rows win the gesture arena over
  /// their group's recognizer, so children drag individually.
  ///
  /// [keyed] is false only for the floating drag copy: a GlobalKey may
  /// appear ONCE in the tree, so the copy must not re-register the main
  /// list's row keys (duplicate GlobalKeys steal elements across subtrees).
  Widget _wrapNode(
    IntervalNode node, {
    required String? parentGroupId,
    required int index,
    bool keyed = true,
  }) {
    final row = switch (node) {
      DefNode(:final def) => _chipRow(def),
      GroupNode(:final group, :final children) =>
        _groupRow(group, children, keyed: keyed),
    };
    return GestureDetector(
      onVerticalDragDown: (d) => _pendingGrab = d.globalPosition,
      onVerticalDragStart: (d) => _dragStart(node, d.globalPosition),
      onVerticalDragUpdate: (d) => _dragUpdate(node.id, d.globalPosition),
      onVerticalDragEnd: (_) => _dragEnd(node.id),
      onVerticalDragCancel: () => _dragAbort(node.id),
      child: keyed ? KeyedSubtree(key: _keyFor(node.id), child: row) : row,
    );
  }

  // ── drag machinery ────────────────────────────────────────────────────

  /// The prospective drop slot: full-height row marker with a thin outline,
  /// rendered inline where the dragged node would land.
  Widget _slotGap() {
    final h = _drag?.rect.height ?? 40;
    return Container(
      key: const Key('drag-slot'),
      height: h,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: AppColors.outline, width: 1.2),
        color: AppColors.card.withValues(alpha: 0.35),
      ),
    );
  }

  void _dragStart(IntervalNode node, Offset global) {
    if (_drag != null) {
      // A second pointer (trackpad palm + finger) or a nested recognizer
      // started a drag while one is live: the new drag takes over — but the
      // previous one MUST be cleaned up first, or its floating overlay
      // entry leaks and keeps rebuilding with no active drag (the
      // "Null check operator" haywire crash).
      _cleanupDrag();
    }
    final rect = _rectOf(node.id);
    if (rect == null) return;
    final grabDy = (_pendingGrab ?? global).dy - rect.top;
    setState(() {
      _drag = _Drag(node, rect, grabDy);
      _pointer = global;
      _target = _slotAt(global);
    });
    _float = OverlayEntry(builder: _buildFloat);
    Overlay.of(context).insert(_float!);
  }

  void _dragUpdate(String nodeId, Offset global) {
    // Ownership guard: recognizers that lost the arena (or belong to a
    // replaced drag) still deliver events — only the live drag may act.
    if (_drag?.node.id != nodeId) return;
    setState(() {
      _pointer = global;
      _target = _slotAt(global);
    });
    _float?.markNeedsBuild();
  }

  /// Drop: apply the slot as one move + clear the selection. A null slot or
  /// a rejected move snaps back with no change. Foreign/stale recognizers
  /// (see [_dragUpdate]) may not commit the live drag.
  void _dragEnd(String nodeId) {
    if (_drag?.node.id != nodeId) return;
    final drag = _drag!;
    final slot = _target;
    _cleanupDrag();
    if (slot == null) return;
    try {
      var index = slot.index;
      if (controller.tree.parentOf(drag.node.id) == slot.parentId &&
          _indexOf(drag.node.id) < index) {
        index -= 1; // engine's index applies AFTER removing the node
      }
      controller.moveNode(
        drag.node.id,
        newParentGroupId: slot.parentId,
        newIndex: index,
      );
      controller.clearSelection();
    } on TreeOpException {
      // Engine rejected the move — snap back with no change.
    }
  }

  /// Cancel (recognizer lost the arena, pointer cancelled): no change.
  /// Ownership-guarded like [_dragEnd] — a losing nested row's cancel must
  /// not abort the live drag.
  void _dragAbort(String nodeId) {
    if (_drag?.node.id != nodeId) return;
    _cleanupDrag();
  }

  void _cleanupDrag() {
    _float?.remove();
    _float = null;
    _pendingGrab = null;
    if (_drag == null && _target == null) return;
    setState(() {
      _drag = null;
      _target = null;
    });
  }

  /// The lifted row floating under the pointer (X locked to its column).
  /// Null-safe: an overlay entry removed during a frame can still build
  /// once in that frame — it must never crash on a late build.
  Widget _buildFloat(BuildContext context) {
    final drag = _drag;
    if (drag == null) return const SizedBox.shrink();
    final row = switch (drag.node) {
      DefNode(:final def) => _chipRow(def),
      GroupNode(:final group, :final children) =>
        _groupRow(group, children, keyed: false),
    };
    return Positioned(
      left: drag.rect.left,
      top: _pointer.dy - drag.grabDy,
      width: drag.rect.width,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.95,
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.5),
            child: row,
          ),
        ),
      ),
    );
  }

  // ── slot computation ──────────────────────────────────────────────────

  /// Maps the pointer to a drop slot (class-doc rules). Returns null when
  /// no legal slot exists (empty list, or the pointer resolved inside the
  /// dragged subtree).
  _Slot? _slotAt(Offset p) {
    final leaves = _leaves();
    if (leaves.isEmpty) return null;

    var k = leaves.indexWhere((l) => l.rect.center.dy > p.dy);
    if (k < 0) k = leaves.length;

    _Slot slot;
    if (k == leaves.length) {
      slot = _Slot(null, controller.tree.roots.length);
    } else {
      slot = _Slot(leaves[k].parentId, leaves[k].index);
    }

    // Bottom chain: the row above the gap may end one or more nested
    // groups; the slot is "end of that group" while the pointer stays
    // inside the group's rect AND over its content column (innermost
    // first — the X gate separates levels whose edges coincide).
    if (k > 0 &&
        (k == leaves.length || leaves[k - 1].parentId != leaves[k].parentId)) {
      String? anc = leaves[k - 1].parentId;
      while (anc != null && _lastLeafId(anc) == leaves[k - 1].id) {
        final g = _rectOf(anc);
        if (g != null && p.dy < g.bottom) {
          final contentLeft = _childrenLeft(anc);
          if (contentLeft == null || p.dx >= contentLeft) {
            return _Slot(anc, _childCount(anc));
          }
        }
        anc = controller.tree.parentOf(anc);
      }
    }

    // Top chain: "before the first child of G" shares its gap with "before
    // G"; lift to the group's own position while the pointer is above the
    // group's rect AND over the group's bracket column (not its content —
    // the X gate separates levels whose edges coincide).
    while (slot.parentId != null && slot.index == 0) {
      final parentId = slot.parentId!;
      final g = _rectOf(parentId);
      if (g == null || p.dy >= g.top) break;
      final contentLeft = _childrenLeft(parentId);
      if (contentLeft != null && p.dx >= contentLeft) break;
      slot = _Slot(controller.tree.parentOf(parentId), _indexOf(parentId));
    }

    if (_isDraggedSubtree(slot.parentId)) return null;
    return slot;
  }

  /// All leaf rows (chips at any depth) in visual pre-order, excluding the
  /// dragged subtree, with their measured global rects.
  List<_RowInfo> _leaves() {
    final out = <_RowInfo>[];
    void walk(List<IntervalNode> nodes, String? parent) {
      for (var i = 0; i < nodes.length; i++) {
        final n = nodes[i];
        if (_isDraggedSubtree(n.id)) continue;
        if (n is DefNode) {
          final r = _rectOf(n.id);
          if (r != null) out.add(_RowInfo(n.id, parent, i, r));
        } else if (n is GroupNode) {
          walk(n.children, n.id);
        }
      }
    }

    walk(controller.tree.roots, null);
    return out;
  }

  /// Global rect of a row by its registered key.
  Rect? _rectOf(String id) {
    final ctx = _rowKeys[id]?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Global X where a group's children column starts (its first child's
  /// row left). At a shared edge gap the pointer's X against this line
  /// picks the nesting level: over the bracket column = this group's
  /// level, over the content column = one level deeper.
  double? _childrenLeft(String groupId) {
    final node = controller.tree.nodeById(groupId);
    if (node is! GroupNode || node.children.isEmpty) return null;
    return _rectOf(node.children.first.id)?.left;
  }

  /// The last leaf (chip) in a node's subtree, in visual order.
  String? _lastLeafId(String nodeId) {
    final n = controller.tree.nodeById(nodeId);
    if (n is DefNode) return n.id;
    if (n is GroupNode) {
      for (var i = n.children.length - 1; i >= 0; i--) {
        final r = _lastLeafId(n.children[i].id);
        if (r != null) return r;
      }
    }
    return null;
  }

  /// Number of children of [parentId] (null = root).
  int _childCount(String? parentId) => parentId == null
      ? controller.tree.roots.length
      : (controller.tree.nodeById(parentId) as GroupNode).children.length;

  /// Index of [nodeId] among its siblings.
  int _indexOf(String nodeId) {
    final parentId = controller.tree.parentOf(nodeId);
    final siblings = parentId == null
        ? controller.tree.roots
        : (controller.tree.nodeById(parentId) as GroupNode).children;
    return siblings.indexWhere((n) => n.id == nodeId);
  }

  /// True for the dragged node and everything inside it.
  bool _isDraggedSubtree(String? id) {
    final d = _drag;
    if (d == null || id == null) return false;
    if (id == d.node.id) return true;
    String? cursor = controller.tree.parentOf(id);
    while (cursor != null) {
      if (cursor == d.node.id) return true;
      cursor = controller.tree.parentOf(cursor);
    }
    return false;
  }

  // ── row widgets ───────────────────────────────────────────────────────

  /// One interval: selection circle | chip card (bordered, label left,
  /// duration right, alert subtitle below). The CARD body is tappable →
  /// edit this def; the selection circle stays independent (it sits
  /// outside the card, so both gestures never overlap).
  Widget _chipRow(IntervalDef def) {
    return Row(
      key: Key('chip-${def.id}'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _selectionCircle(def.id),
        const SizedBox(width: 10),
        // Builder: the tap needs a context and _chipRow has none of its
        // own (same trick as the bracket tap below).
        Expanded(
          child: Builder(
            builder: (context) => GestureDetector(
              key: Key('chip-tap-${def.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _openIntervalEditor(context, defId: def.id),
              child: _chipCard(def),
            ),
          ),
        ),
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
  /// on top, tappable bar → repeat stepper, see [_bracketTapped]) | the
  /// children stacked inside, recursively — so nested groups stack their
  /// bracket columns further right (UI-REFERENCE items 9–10).
  Widget _groupRow(
    GroupDef group,
    List<IntervalNode> children, {
    bool keyed = true,
  }) {
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
                  // Builder: the bracket tap needs a context and _groupRow
                  // has none of its own; opaque so the bare glyph area is
                  // hittable where no child covers the tap point.
                  child: Builder(
                    builder: (context) => GestureDetector(
                      key: Key('bracket-${group.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _bracketTapped(context, group),
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
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _rows(
                      children,
                      parentGroupId: group.id,
                      keyed: keyed,
                    ),
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

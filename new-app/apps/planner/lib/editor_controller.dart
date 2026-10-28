import 'package:flutter/foundation.dart';
import 'package:planner_engine/planner_engine.dart';

/// Working-copy controller for the interval-timer editor (P4.1).
///
/// Edits mutate an in-memory copy only: [name], [color], and [tree] start
/// from the persisted timer/tree and are NEVER written back individually —
/// in-editor mutations (rename, color, add/duplicate/delete/move, undo) stay
/// in this working copy. The commit is the logged unit: [commit] persists the
/// whole tree via one `editor.commit` change-log event plus, when the name or
/// color changed, one `timer.update` event (the store appends each event
/// itself). Closing with ✕ (no commit) simply drops the controller — the
/// discard is implicit, nothing was ever written.
///
/// Undo is a snapshot stack ([_Snapshot], newest last, capped at 50): every
/// mutating op pushes the current state FIRST, then applies exactly one field
/// change or one pure [IntervalTree] op — one toolbar action = one undo step.
/// [toggleSelect] is deliberately not an undo step (selection is view state,
/// not a mutation).
///
/// Tree-op input errors ([TreeOpException] from the engine) are not caught
/// here — they propagate; the screen only guards the drag-drop path.
class EditorController extends ChangeNotifier {
  EditorController({
    required this.store,
    required this.timer,
    required IntervalTree initialTree,
  }) : name = timer.name,
       color = timer.color,
       tree = initialTree;

  /// Persistence seam — only [commit] touches it.
  final Store store;

  /// The timer being edited; its current name/color seed the working copy.
  final IntervalTimer timer;

  /// Working-copy timer name (persisted only on [commit]).
  String name;

  /// Working-copy timer color hex (persisted only on [commit]).
  String color;

  /// Working-copy interval tree — all structural edits land here.
  IntervalTree tree;

  /// Selected node ids (def or group), multi-select. Not part of undo.
  final Set<String> selection = <String>{};

  /// Snapshot stack, newest last.
  final List<_Snapshot> _undo = <_Snapshot>[];

  /// Max undo depth (~50 mutations, oldest dropped).
  static const int _undoLimit = 50;

  /// Whether at least one mutation can be undone.
  bool get canUndo => _undo.isNotEmpty;

  /// Whether any node is selected (enables duplicate/delete).
  bool get hasSelection => selection.isNotEmpty;

  /// Captures the current working copy BEFORE a mutation is applied.
  void _pushUndo() {
    _undo.add(
      (
        name: name,
        color: color,
        tree: tree,
        selection: Set<String>.of(selection),
      ),
    );
    if (_undo.length > _undoLimit) {
      _undo.removeAt(0);
    }
  }

  /// Plain tap on a selection circle: adds the id if absent, removes it if
  /// present (multi-select). Not a mutation → no undo step.
  void toggleSelect(String nodeId) {
    if (!selection.remove(nodeId)) {
      selection.add(nodeId);
    }
    notifyListeners();
  }

  /// Sets the selection to EXACTLY [nodeId], collapsing any multi-select.
  /// Like [toggleSelect], selection is view state → no undo step.
  void selectOnly(String nodeId) {
    selection
      ..clear()
      ..add(nodeId);
    notifyListeners();
  }

  /// Working-copy rename (undo-pushing).
  void rename(String newName) {
    _pushUndo();
    name = newName;
    notifyListeners();
  }

  /// Working-copy color change (undo-pushing).
  void setColor(String hex) {
    _pushUndo();
    color = hex;
    notifyListeners();
  }

  /// Appends a new [DefNode] at the END of the roots (fresh UUIDv4, this
  /// timer). Exists for the empty-state add affordance and tests — the "+"
  /// toolbar button routes to the interval editor (P4.3) instead.
  /// [name] is nullable: a blank label is stored as an unnamed interval.
  void addInterval({
    required String? name,
    required String color,
    required int durationSeconds,
    required bool autoFinish,
    String? endAlertSoundFile,
  }) {
    _pushUndo();
    final node = DefNode(
      IntervalDef(
        id: newUuidV4(),
        timerId: timer.id,
        name: name,
        color: color,
        durationSeconds: durationSeconds,
        autoFinish: autoFinish,
        endAlertSoundFile: endAlertSoundFile,
      ),
    );
    tree = IntervalTree([...tree.roots, node]);
    notifyListeners();
  }

  /// Replaces one def's contents (undo step); used by the interval editor's
  /// back-commit. Throws StateError if [defId] is not a DefNode in the tree
  /// — absent ids surface [IntervalTree.nodeById]'s [TreeOpException] as
  /// StateError too — and if [newDef] does not keep that def's id/timerId
  /// (identity is not editable). Validation runs BEFORE the undo push.
  void replaceDef(String defId, IntervalDef newDef) {
    final IntervalNode node;
    try {
      node = tree.nodeById(defId);
    } on TreeOpException {
      throw StateError('replaceDef: no node with id $defId in the tree');
    }
    if (node is! DefNode) {
      throw StateError('replaceDef: node $defId is not a DefNode');
    }
    if (newDef.id != defId || newDef.timerId != node.def.timerId) {
      throw StateError(
        'replaceDef: newDef must keep id $defId and timerId '
        '${node.def.timerId}',
      );
    }
    _pushUndo();
    tree = IntervalTree(_replaceDefIn(tree.roots, defId, newDef));
    notifyListeners();
  }

  /// Deep-copies the selected siblings below the last selected node (P1.1
  /// semantics). Selection is kept unchanged.
  void duplicateSelection() {
    _pushUndo();
    tree = tree.duplicated(selection.toList(), newId: newUuidV4);
    notifyListeners();
  }

  /// Removes the selected subtrees (emptied groups cascade); the deleted
  /// ids leave the selection with them.
  void deleteSelection() {
    _pushUndo();
    tree = tree.withoutNodes(selection.toList());
    selection.clear();
    notifyListeners();
  }

  /// Repositions a subtree (P1.1 semantics; the engine rejects invalid
  /// targets such as a group moved into its own subtree).
  void moveNode(
    String nodeId, {
    required String? newParentGroupId,
    required int newIndex,
  }) {
    _pushUndo();
    tree = tree.moved(
      nodeId,
      newParentGroupId: newParentGroupId,
      newIndex: newIndex,
    );
    notifyListeners();
  }

  // ── group / ungroup ───────────────────────────────────────────────────
  //
  // Grouping acts on the TOPMOST layer of the selection (selected ids not
  // nested inside another selected id) and requires that layer to be a run
  // of CONTIGUOUS siblings — stricter than the engine's
  // [IntervalTree.grouped], which tolerates non-adjacent siblings by
  // pulling them together (a UI choice: the toolbar only offers grouping
  // for adjacent runs). Ungrouping targets ROOT-LEVEL groups only, exactly
  // one per action: inner groups are unreachable by design until the group
  // holding them is dissolved (mirrors MultiTimer).

  /// Whether the topmost selection is a non-empty run of contiguous
  /// siblings — exactly the precondition of [groupSelection].
  bool get canGroup {
    final topmost = _topmostSelected();
    return topmost.isNotEmpty && _areContiguousSiblings(topmost);
  }

  /// Wraps the topmost selected siblings in a fresh group (repeat 1),
  /// selects that group, and RETURNS its id so callers can open the repeat
  /// modal for it. One undo step. Throws [StateError] when ![canGroup].
  String groupSelection() {
    final topmost = _topmostSelected();
    if (topmost.isEmpty || !_areContiguousSiblings(topmost)) {
      throw StateError(
        'groupSelection: selection is not a run of contiguous siblings',
      );
    }
    _pushUndo();
    final newGroupId = newUuidV4();
    tree = tree.grouped(topmost, newGroupId: newGroupId, repeatCount: 1);
    selection
      ..clear()
      ..add(newGroupId);
    notifyListeners();
    return newGroupId;
  }

  /// Whether a selected id is a root-level [GroupNode] (inner groups are
  /// unreachable by design — see the group section note above).
  bool get canUngroup => _selectedRootGroupId() != null;

  /// Dissolves the FIRST selected root-level group (in root order — exactly
  /// ONE group per action) and clears the selection. One undo step. Throws
  /// [StateError] when ![canUngroup].
  void ungroupSelection() {
    final groupId = _selectedRootGroupId();
    if (groupId == null) {
      throw StateError('ungroupSelection: no root-level group selected');
    }
    _pushUndo();
    tree = tree.ungrouped(groupId);
    selection.clear();
    notifyListeners();
  }

  /// Replaces [groupId]'s def with one carrying [repeat] total passes
  /// (>= 1), keeping its children. One undo step; [repeat] < 1 throws
  /// [ArgumentError] BEFORE anything is pushed.
  void setGroupRepeat(String groupId, int repeat) {
    if (repeat < 1) {
      throw ArgumentError.value(repeat, 'repeat', 'must be >= 1');
    }
    _pushUndo();
    tree = _treeWithRepeat(tree, groupId, repeat);
    notifyListeners();
  }

  /// The selected ids NOT nested inside another selected id — the
  /// outermost layer of the selection, by walking parents via parentOf.
  List<String> _topmostSelected() {
    final topmost = <String>[];
    for (final id in selection) {
      var ancestor = tree.parentOf(id);
      var nested = false;
      while (ancestor != null) {
        if (selection.contains(ancestor)) {
          nested = true;
          break;
        }
        ancestor = tree.parentOf(ancestor);
      }
      if (!nested) topmost.add(id);
    }
    return topmost;
  }

  /// Whether [ids] all share one parent AND occupy consecutive positions
  /// in that parent's child order.
  bool _areContiguousSiblings(List<String> ids) {
    if (ids.isEmpty) return false;
    final parentId = tree.parentOf(ids.first);
    final indices = <int>[];
    for (final id in ids) {
      if (tree.parentOf(id) != parentId) return false; // not siblings
      indices.add(_siblingIndex(id, parentId));
    }
    indices.sort();
    for (var i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) return false; // not adjacent
    }
    return true;
  }

  /// Position of [id] within [parentId]'s children (null parent = roots).
  int _siblingIndex(String id, String? parentId) {
    final siblings = parentId == null
        ? tree.roots
        : (tree.nodeById(parentId) as GroupNode).children;
    return siblings.indexWhere((node) => node.id == id);
  }

  /// First selected id (in root order) that is a root-level [GroupNode].
  String? _selectedRootGroupId() {
    for (final node in tree.roots) {
      if (node is GroupNode && selection.contains(node.id)) return node.id;
    }
    return null;
  }

  /// Pure recursive rebuild: a copy of [current] where [groupId]'s def
  /// carries [repeatCount]; every other node (and all children) untouched.
  IntervalTree _treeWithRepeat(
    IntervalTree current,
    String groupId,
    int repeatCount,
  ) => IntervalTree([
    for (final node in current.roots)
      _nodeWithRepeat(node, groupId, repeatCount),
  ]);

  IntervalNode _nodeWithRepeat(
    IntervalNode node,
    String groupId,
    int repeatCount,
  ) => switch (node) {
    DefNode() => node,
    GroupNode(:final group, :final children) => GroupNode(
      group.id == groupId
          ? GroupDef(
              id: group.id,
              timerId: group.timerId,
              repeatCount: repeatCount,
            )
          : group,
      [for (final child in children) _nodeWithRepeat(child, groupId, repeatCount)],
    ),
  };

  /// Pure recursive rebuild: a copy of [nodes] where the [DefNode] with
  /// [defId] carries [newDef]; every other node keeps its contents — groups
  /// rebuild so their children are visited too (one matching def swaps in
  /// place, nothing else moves).
  List<IntervalNode> _replaceDefIn(
    List<IntervalNode> nodes,
    String defId,
    IntervalDef newDef,
  ) => [
    for (final node in nodes)
      switch (node) {
        DefNode(:final def) => def.id == defId ? DefNode(newDef) : node,
        GroupNode(:final group, :final children) =>
          GroupNode(group, _replaceDefIn(children, defId, newDef)),
      },
  ];

  /// Pops the newest snapshot and restores name/color/tree/selection.
  /// No-op when the stack is empty; never pushes.
  void undo() {
    if (_undo.isEmpty) return;
    final snapshot = _undo.removeLast();
    name = snapshot.name;
    color = snapshot.color;
    tree = snapshot.tree;
    selection
      ..clear()
      ..addAll(snapshot.selection);
    notifyListeners();
  }

  /// Persists the working copy as ONE logged unit (see class doc):
  /// `editor.commit` carries the tree save plus the working name/color, and
  /// `timer.update` follows only when name or color differ from [timer]'s.
  Future<void> commit() async {
    await store.saveTree(
      timer.id,
      tree,
      eventKind: 'editor.commit',
      eventPayload: {'name': name, 'color': color},
    );
    if (name != timer.name || color != timer.color) {
      await store.updateTimer(timer.id, name: name, color: color);
    }
  }

  /// Clears the undo stack. Discarding the edits themselves is implicit:
  /// the caller simply drops this controller without [commit].
  void revert() {
    _undo.clear();
    notifyListeners();
  }
}

/// One undo step: the full working copy captured before a mutation.
typedef _Snapshot = ({
  String name,
  String color,
  IntervalTree tree,
  Set<String> selection,
});

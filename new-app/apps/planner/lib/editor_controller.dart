import 'package:flutter/foundation.dart';
import 'package:planner_engine/planner_engine.dart';

/// Authoring-rule reasons (v2 dated/repeat exclusivity, P1.5) shown at the
/// blocked interaction: the drag-drop path and the Time toggle share the
/// first, the repeat modal the second.
const String kDatedInRepeatingGroupReason =
    "A dated interval can't be added to a repeating group.";
const String kRepeatingGroupWithDatedReason =
    "This group contains a dated interval, so it can't repeat.";

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
    this.resolveTimer,
  }) : name = timer.name,
       color = timer.color,
       tree = initialTree;

  /// Persistence seam — only [commit] touches it.
  final Store store;

  /// The timer being edited; its current name/color seed the working copy.
  final IntervalTimer timer;

  /// Resolves the timer a [commit] writes (P4.1): null = commit straight
  /// to [timer]; a date-bound board passes `AppController.timerForWrite`,
  /// which materializes the day's own copy first and returns it — the
  /// commit IS the day's first write, so it must land on the copy and
  /// never on the placeholder.
  final Future<IntervalTimer> Function()? resolveTimer;

  /// Working-copy timer name (persisted only on [commit]).
  String name;

  /// Working-copy timer color hex (persisted only on [commit]).
  String color;

  /// Working-copy interval tree — all structural edits land here.
  IntervalTree tree;

  /// Selected node ids (def or group), multi-select. Not part of undo.
  /// Last END-ALERT sound used by a saved def — the default for NEW
  /// intervals (acceptance: "New Interval Default Sound").
  String? lastSound;

  /// The selection circles of the tree rows (view state — never restored
  /// by undo, cleared by every action that acts on nodes).
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

  /// Drops the whole selection (drag-reorder and other list actions clear
  /// selection when they act on a node). View state → no undo step.
  void clearSelection() {
    if (selection.isEmpty) return;
    selection.clear();
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
  /// [durationSeconds] is nullable too (v2 P1.2): null = **Open** (no
  /// duration); [triggerTimeSeconds] non-null = **dated** (a wall at that
  /// time-of-day, seconds since midnight) — both flow straight into the
  /// def the editor commits.
  void addInterval({
    required String? name,
    required String color,
    required int? durationSeconds,
    required bool autoFinish,
    String? endAlertSoundFile,
    int? triggerTimeSeconds,
  }) {
    _pushUndo();
    if (endAlertSoundFile != null) lastSound = endAlertSoundFile;
    final node = DefNode(
      IntervalDef(
        id: newUuidV4(),
        timerId: timer.id,
        name: name,
        color: color,
        durationSeconds: durationSeconds,
        autoFinish: autoFinish,
        endAlertSoundFile: endAlertSoundFile,
        triggerTimeSeconds: triggerTimeSeconds,
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
    if (newDef.endAlertSoundFile != null) {
      lastSound = newDef.endAlertSoundFile;
    }
    tree = IntervalTree(_replaceDefIn(tree.roots, defId, newDef));
    notifyListeners();
  }

  /// Deep-copies the selected siblings below the last selected node (P1.1
  /// semantics). Selection is CLEARED (action rule).
  /// Tweaks #4 — Alt+Up/Down: moves the focused node + the selection as
  /// ONE contiguous block ("gather"). Returns whether anything moved.
  ///
  /// Rules: the block keeps members' row order and steps PAST exactly one
  /// non-member row in [dir] (+1 down / -1 up) — a blocked edge is a
  /// no-op, never a half move. The block re-inserts contiguous at the
  /// position just beyond that passed row: passing a group header row
  /// downward enters the group (first child slot), passing it upward
  /// leaves the group (above it). Mixed-depth selections flatten to the
  /// destination parent. Selected groups move as subtrees; a member with
  /// a member-ancestor rides along inside it and is dropped from the
  /// list. One call = one undo step.
  bool moveBlockBy(int dir, String focusedId) {
    final rows = _flatRows();
    final idxOf = <String, int>{};
    for (var i = 0; i < rows.length; i++) {
      idxOf[rows[i].id] = i;
    }
    // The moving set: focused + selected, ancestor-deduped.
    final raw = <String>{focusedId, ...selection};
    final members = <String>[
      for (final id in raw)
        if (idxOf.containsKey(id) && !_hasAncestorIn(id, raw)) id,
    ];
    if (members.isEmpty) return false;
    members.sort((a, b) => idxOf[a]!.compareTo(idxOf[b]!));
    final moving = <String>{};
    for (final id in members) {
      _collectIds(tree.nodeById(id), moving);
    }
    // The first row beyond the block that is not moving = the row the
    // block steps past.
    final lead = dir > 0 ? idxOf[members.last]! : idxOf[members.first]!;
    var w = -1;
    for (var i = lead + dir; i >= 0 && i < rows.length; i += dir) {
      if (!moving.contains(rows[i].id)) {
        w = i;
        break;
      }
    }
    if (w < 0) return false; // block at the edge
    final wRow = rows[w];
    String? parent;
    String? anchorSibling;
    var after = false;
    var fallback = 0;
    if (dir > 0 && wRow.isGroup) {
      // Down past a group header = INTO the group, first child slot.
      parent = wRow.id;
      final g = tree.nodeById(wRow.id) as GroupNode;
      if (g.children.isNotEmpty) {
        anchorSibling = g.children.first.id;
      } else {
        fallback = 0;
      }
    } else {
      // Down past a normal row = after it; up past ANY row = before it
      // (for a group header that is outside the group).
      parent = wRow.parentId;
      anchorSibling = wRow.id;
      after = dir > 0;
    }
    // v2 exclusivity (P1.5): a block containing a dated interval may not
    // land inside a repeating group — checked BEFORE the undo push, so a
    // blocked move is a no-op like a blocked edge.
    if (parent != null &&
        insideRepeatingGroup(parent) &&
        members.any(subtreeContainsDated)) {
      return false;
    }
    _pushUndo();
    var anchor = anchorSibling;
    for (final id in members) {
      final kids = parent == null
          ? tree.roots
          : (tree.nodeById(parent) as GroupNode).children;
      final ai =
          anchor == null ? -1 : kids.indexWhere((n) => n.id == anchor);
      int idx;
      if (ai < 0) {
        idx = fallback;
      } else {
        idx = ai + (after ? 1 : 0);
        // moved() inserts at a POST-removal index — a member sitting
        // before the anchor in the same parent shifts it left by one.
        final mi = kids.indexWhere((n) => n.id == id);
        if (mi >= 0 && mi < ai) idx -= 1;
      }
      tree = tree.moved(id,
          newParentGroupId: parent,
          newIndex: idx < kids.length ? idx : kids.length);
      anchor = id;
      after = true;
    }
    notifyListeners();
    return true;
  }

  /// Grid rows in reading order (pre-order) with each row's slot.
  List<({String id, String? parentId, bool isGroup})> _flatRows() {
    final rows = <({String id, String? parentId, bool isGroup})>[];
    void walk(List<IntervalNode> nodes, String? parentId) {
      for (final n in nodes) {
        rows.add((
          id: n.id,
          parentId: parentId,
          isGroup: n is GroupNode,
        ));
        if (n is GroupNode) walk(n.children, n.id);
      }
    }

    walk(tree.roots, null);
    return rows;
  }

  /// Adds [node]'s whole subtree to [out].
  void _collectIds(IntervalNode node, Set<String> out) {
    out.add(node.id);
    if (node is GroupNode) {
      for (final c in node.children) {
        _collectIds(c, out);
      }
    }
  }

  /// True when another member of [set] is an ancestor of [id].
  bool _hasAncestorIn(String id, Set<String> set) {
    var cursor = tree.parentOf(id);
    while (cursor != null) {
      if (set.contains(cursor)) return true;
      cursor = tree.parentOf(cursor);
    }
    return false;
  }

  /// Duplicates the selected subtrees; returns the NEW ids in selection
  /// order (callers move focus to the first copy — tweaks #3).
  List<String> duplicateSelection() => duplicateNodes(selection.toList());

  /// Duplicates [ids] (each copy is inserted after its source) and returns
  /// the new ids in the given order. The selection is cleared — focus
  /// lands on the copies instead (tweaks #3/#6).
  List<String> duplicateNodes(List<String> ids) {
    _pushUndo();
    final created = <String>[];
    tree = tree.duplicated(ids, newId: () {
      final id = newUuidV4();
      created.add(id);
      return id;
    });
    selection.clear();
    notifyListeners();
    return created;
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
  /// targets such as a group moved into its own subtree). v2 exclusivity
  /// (P1.5): a subtree containing a dated interval may not enter a group
  /// chain that repeats — [StateError] BEFORE the undo push (the screen
  /// guards the drag path itself and shows the reason instead).
  void moveNode(
    String nodeId, {
    required String? newParentGroupId,
    required int newIndex,
  }) {
    if (newParentGroupId != null &&
        insideRepeatingGroup(newParentGroupId) &&
        subtreeContainsDated(nodeId)) {
      throw StateError(
        'moveNode: a dated interval cannot enter a repeating group',
      );
    }
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
  /// CLEARS the selection (action rule — the group is NOT auto-selected),
  /// and RETURNS the new group's id so callers can open the repeat modal
  /// for it. One undo step. Throws [StateError] when ![canGroup].
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
    selection.clear();
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
  /// [ArgumentError] BEFORE anything is pushed. v2 exclusivity (P1.5):
  /// a group whose subtree contains a dated interval cannot repeat above
  /// 1 — [StateError] BEFORE the undo push (the repeat modal blocks the
  /// interaction inline instead).
  void setGroupRepeat(String groupId, int repeat) {
    if (repeat < 1) {
      throw ArgumentError.value(repeat, 'repeat', 'must be >= 1');
    }
    if (repeat > 1 && subtreeContainsDated(groupId)) {
      throw StateError(
        'setGroupRepeat: a group containing a dated interval cannot repeat',
      );
    }
    _pushUndo();
    tree = _treeWithRepeat(tree, groupId, repeat);
    selection.clear(); // action rule: nothing stays selected
    notifyListeners();
  }

  // ── v2 dated/repeat exclusivity (P1.5) ─────────────────────────────
  //
  // A dated interval (triggerTimeSeconds != null) never lives inside a
  // repeating group: the authoring interactions enforce it (drag-drop,
  // the Time toggle, the repeat modal) and the mutation guards below are
  // the defense in depth.

  /// True when the subtree rooted at [nodeId] contains a dated interval
  /// anywhere (the node itself included).
  bool subtreeContainsDated(String nodeId) =>
      _subtreeContainsDated(tree.nodeById(nodeId));

  bool _subtreeContainsDated(IntervalNode node) => switch (node) {
    DefNode(:final def) => def.isDated,
    GroupNode(:final children) => children.any(_subtreeContainsDated),
  };

  /// True when [groupId] itself or any of its ancestor groups repeats
  /// (repeatCount > 1) — i.e. anything placed there runs more than once.
  /// Null (the roots) is never repeating.
  bool insideRepeatingGroup(String? groupId) {
    String? cursor = groupId;
    while (cursor != null) {
      final node = tree.nodeById(cursor);
      if (node is GroupNode && node.group.repeatCount > 1) return true;
      cursor = tree.parentOf(cursor);
    }
    return false;
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

  /// Pops the newest snapshot and restores name/color/tree. The SELECTION
  /// is NOT restored — an action never leaves a selection behind
  /// (acceptance: "undoing a grouping results in the intervals being
  /// selected … simply shouldn't happen"). No-op when the stack is empty;
  /// never pushes.
  void undo() {
    if (_undo.isEmpty) return;
    final snapshot = _undo.removeLast();
    name = snapshot.name;
    color = snapshot.color;
    tree = snapshot.tree;
    selection.clear();
    notifyListeners();
  }

  /// Persists the working copy as ONE logged unit (see class doc):
  /// `editor.commit` carries the tree save plus the working name/color, and
  /// `timer.update` follows only when name or color differ from the
  /// target's — [resolveTimer]'s answer when one is wired (P4.1: a
  /// date-bound board hands back its materialized copy), else [timer].
  Future<void> commit() async {
    final target = await resolveTimer?.call() ?? timer;
    // P4.1: a date-bound commit resolves to the day's COPY, while the
    // working tree was seeded from the placeholder — re-target it (ids
    // and values untouched) so saveTree's ownership check accepts it.
    final toSave = target.id == timer.id ? tree : _rebasedTo(tree, target.id);
    await store.saveTree(
      target.id,
      toSave,
      eventKind: 'editor.commit',
      eventPayload: {'name': name, 'color': color},
    );
    if (name != target.name || color != target.color) {
      await store.updateTimer(target.id, name: name, color: color);
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

/// P4.1 — [tree] with every node owned by [timerId]: ids and all values
/// untouched, only the owning timer changes. The editor's working copy
/// carries the timer it was SEEDED from (the placeholder on an
/// unmaterialized day); a commit that resolved to the day's own copy
/// ([EditorController.resolveTimer]) writes this rebased shape, which is
/// exactly what `saveTree`'s ownership check demands.
IntervalTree _rebasedTo(IntervalTree tree, String timerId) => IntervalTree([
  for (final n in tree.roots) _rebasedNode(n, timerId),
]);

IntervalNode _rebasedNode(IntervalNode node, String timerId) =>
    switch (node) {
      DefNode(:final def) => DefNode(
        IntervalDef(
          id: def.id,
          timerId: timerId,
          name: def.name,
          color: def.color,
          durationSeconds: def.durationSeconds,
          autoFinish: def.autoFinish,
          endAlertSoundFile: def.endAlertSoundFile,
          completed: def.completed,
          triggerTimeSeconds: def.triggerTimeSeconds,
        ),
      ),
      GroupNode(:final group, :final children) => GroupNode(
        GroupDef(
          id: group.id,
          timerId: timerId,
          repeatCount: group.repeatCount,
        ),
        [for (final c in children) _rebasedNode(c, timerId)],
      ),
    };

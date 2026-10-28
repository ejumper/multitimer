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
  void addInterval({
    required String name,
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

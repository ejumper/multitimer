import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/editor_controller.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// EditorController unit tests (P4.1 working-copy semantics): discard vs
/// commit, duplicate/delete/move through the pure tree ops, snapshot undo
/// (one action = one step), and selection toggling — over a real in-memory
/// drift store on a fixed clock, no widgets.
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late Board board;
  late IntervalTimer timer;
  late EditorController controller;

  DefNode def(String id, {String? name, int seconds = 60}) => DefNode(
    IntervalDef(
      id: id,
      timerId: timer.id,
      name: name,
      color: '#0055ff',
      durationSeconds: seconds,
      autoFinish: false,
    ),
  );

  GroupNode groupOf(
    String id,
    List<IntervalNode> children, {
    int repeat = 1,
  }) => GroupNode(
    GroupDef(id: id, timerId: timer.id, repeatCount: repeat),
    children,
  );

  /// Saves [tree] as the timer's definition and builds an editor controller
  /// over it — the store and the working copy start out identical.
  Future<EditorController> buildEditor(IntervalTree tree) async {
    await store.saveTree(timer.id, tree, eventKind: 'tree.save');
    return EditorController(store: store, timer: timer, initialTree: tree);
  }

  setUp(() async {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);
    board = await store.createBoard('My Board');
    timer = await store.createTimer(
      boardId: board.id,
      name: 'Interval timer',
      color: '#0055ff',
    );
    controller = await buildEditor(
      IntervalTree([def('a', name: 'break'), def('b', name: 'Cards')]),
    );
  });

  tearDown(() async {
    controller.dispose();
    await store.close();
  });

  // 1. ✕ (revert) persists nothing: the store still holds the original
  //    tree and timer fields — the working copy is simply dropped.
  test('close_reverts_all_edits', () async {
    final originalTree = (await store.loadTree(timer.id)).toDebugString();

    controller.rename('Focus');
    controller.setColor('#ff00b1');
    controller.addInterval(
      name: 'Stretch',
      color: '#00ad6b',
      durationSeconds: 45,
      autoFinish: true,
    );
    expect(controller.canUndo, isTrue);

    controller.revert();
    expect(controller.canUndo, isFalse);

    expect((await store.loadTree(timer.id)).toDebugString(), originalTree);
    expect(originalTree, 'def:a | def:b');
    final storedTimer = (await store.timersInBoard(board.id)).single;
    expect(storedTimer.name, 'Interval timer');
    expect(storedTimer.color, '#0055ff');
  });

  // 2. Done persists the working copy: tree matches the store, the timer
  //    name is updated, and the change log carries an editor.commit event.
  test('done_persists_edits', () async {
    controller.toggleSelect('b');
    controller.rename('Focus');
    controller.addInterval(
      name: 'Stretch',
      color: '#00ad6b',
      durationSeconds: 45,
      autoFinish: true,
    );
    controller.deleteSelection(); // b selected → removed
    expect(controller.tree.roots.length, 2); // a + the added interval

    await controller.commit();

    final storedTree = await store.loadTree(timer.id);
    expect(storedTree.toDebugString(), controller.tree.toDebugString());
    expect(storedTree.roots.length, 2); // a + the added interval
    final storedTimer = (await store.timersInBoard(board.id)).single;
    expect(storedTimer.name, 'Focus');
    final events = await store.events();
    expect(events.map((e) => e.kind), contains('editor.commit'));
  });

  // 3. Sequential selection: copies land below b, in order, fresh ids —
  //    4 nodes total.
  test('duplicate_sequential_selection_via_ui', () {
    controller.toggleSelect('a');
    controller.toggleSelect('b');
    controller.duplicateSelection();

    final roots = controller.tree.roots;
    expect(roots.length, 4);
    expect([for (final n in roots) n.id].sublist(0, 2), ['a', 'b']);
    final copies = roots.sublist(2).cast<DefNode>();
    expect(copies[0].def.name, 'break'); // a' below b…
    expect(copies[1].def.name, 'Cards'); // …then b'
    expect(copies[0].id, isNot('a'));
    expect(copies[1].id, isNot('b'));
    expect(controller.tree.allIds.toSet().length, 4);
  });

  // 4. Non-sequential selection [c,a]: P1.1 — copies in relative order,
  //    inserted below the LAST selected node → [a, b, c, a', c'].
  test('duplicate_non_sequential_selection_via_ui', () async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([
        def('a', name: 'A'),
        def('b', name: 'B'),
        def('c', name: 'C'),
      ]),
    );

    controller.toggleSelect('c');
    controller.toggleSelect('a');
    controller.duplicateSelection();

    final roots = controller.tree.roots;
    expect(roots.length, 5);
    expect([for (final n in roots) n.id].sublist(0, 3), ['a', 'b', 'c']);
    expect((roots[3] as DefNode).def.name, 'A'); // a' keeps relative order
    expect((roots[4] as DefNode).def.name, 'C'); // below the last selected
    expect(controller.tree.allIds.toSet().length, 5);
  });

  // 5. Deleting a def AND a group (with children): both gone; the emptied
  //    parent of the deleted def cascades away too; selection clears.
  test('delete_chip_and_group_via_ui', () async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([
        groupOf('g1', [def('x', name: 'X')]),
        def('y', name: 'Y'),
        groupOf('g2', [def('z', name: 'Z')]),
      ]),
    );

    controller.toggleSelect('x'); // inside g1 → g1 empties → cascades
    controller.toggleSelect('g2');
    controller.deleteSelection();

    expect(controller.tree.toDebugString(), 'def:y');
    expect(controller.tree.allIds, ['y']);
    expect(controller.selection, isEmpty);
    expect(controller.hasSelection, isFalse);
  });

  // 6. Reorder across group boundaries: a into the group, then b out to
  //    root at index 0.
  test('reorder_across_group_boundaries', () async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([def('a'), groupOf('g1', [def('b')])]),
    );

    controller.moveNode('a', newParentGroupId: 'g1', newIndex: 0);
    expect(controller.tree.toDebugString(), 'group:g1[1]{def:a | def:b}');

    controller.moveNode('b', newParentGroupId: null, newIndex: 0);
    expect(controller.tree.toDebugString(), 'def:b | group:g1[1]{def:a}');
  });

  // 7. Snapshot undo: three mutations walk back step-by-step with exact
  //    intermediate states (one action = one step), then the stack is dry.
  test('undo_walks_back_mutations', () {
    controller.toggleSelect('b'); // selection is not an undo step
    expect(controller.canUndo, isFalse);

    controller.rename('Focus');
    controller.addInterval(
      name: 'Stretch',
      color: '#00ad6b',
      durationSeconds: 45,
      autoFinish: true,
    );
    expect(controller.tree.roots.length, 3); // a, b, Stretch
    controller.deleteSelection(); // b selected → gone, selection cleared
    expect(controller.tree.roots.length, 2); // a, Stretch
    expect(controller.selection, isEmpty);

    // Undo the delete: name unchanged (rename is still two steps back),
    // b and its selection come back.
    controller.undo();
    expect(controller.name, 'Focus');
    expect(controller.tree.roots.length, 3);
    expect(controller.selection, isEmpty); // action rule: never restored

    // Undo the add: back to the original two defs, name still 'Focus'.
    controller.undo();
    expect(controller.name, 'Focus');
    expect(controller.tree.toDebugString(), 'def:a | def:b');

    // Undo the rename: original name restored — and the stack is empty.
    controller.undo();
    expect(controller.name, 'Interval timer');
    expect(controller.tree.toDebugString(), 'def:a | def:b');
    expect(controller.canUndo, isFalse);

    // Further undo is a no-op.
    controller.undo();
    expect(controller.name, 'Interval timer');
    expect(controller.canUndo, isFalse);
  });

  // 8. Selection circles toggle membership (multi-select) and never touch
  //    the undo stack.
  test('selection_circles_multi_select', () {
    expect(controller.hasSelection, isFalse);

    controller.toggleSelect('a');
    expect(controller.selection, {'a'});
    expect(controller.canUndo, isFalse);

    controller.toggleSelect('b'); // multi-select accumulates
    expect(controller.selection, unorderedEquals(['a', 'b']));
    expect(controller.hasSelection, isTrue);

    controller.toggleSelect('a'); // toggling again removes
    expect(controller.selection, {'b'});
    expect(controller.canUndo, isFalse);
  });

  // 9. Grouping a contiguous run — three sub-scenarios, each over a fresh
  //    controller: a single node, a middle pair, and a re-group of [c, d]
  //    after an earlier grouping reshaped the root positions.
  test('group_one_two_three_consecutive', () async {
    // (1) [a] → G{a} at the head of the roots; selection follows the new
    // group so the repeat modal can open for it.
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([def('a'), def('b'), def('c'), def('d')]),
    );
    controller.toggleSelect('a');
    expect(controller.canGroup, isTrue);
    final g1 = controller.groupSelection();
    expect(
      controller.tree.toDebugString(),
      'group:$g1[1]{def:a} | def:b | def:c | def:d',
    );
    expect(controller.selection, isEmpty); // action rule: cleared

    // (2) [b, c] → G{b, c} between a and d.
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([def('a'), def('b'), def('c'), def('d')]),
    );
    controller.toggleSelect('b');
    controller.toggleSelect('c');
    expect(controller.canGroup, isTrue);
    final g2 = controller.groupSelection();
    expect(
      controller.tree.toDebugString(),
      'def:a | group:$g2[1]{def:b | def:c} | def:d',
    );
    expect(controller.selection, isEmpty); // action rule: cleared

    // (3) Grouping [a, b] first reshapes the root positions; the shifted
    // [c, d] run is still contiguous and groups as a third group.
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([def('a'), def('b'), def('c'), def('d')]),
    );
    controller.toggleSelect('a');
    controller.toggleSelect('b');
    final g3 = controller.groupSelection();
    controller.selectOnly('c');
    controller.toggleSelect('d');
    expect(controller.canGroup, isTrue);
    final g4 = controller.groupSelection();
    expect(
      controller.tree.toDebugString(),
      'group:$g3[1]{def:a | def:b} | group:$g4[1]{def:c | def:d}',
    );
    expect(controller.selection, isEmpty); // action rule: cleared
  });

  // 10. Scattered selections are NOT groupable: [a, c] over [a, b, c]
  //     fails canGroup, and groupSelection throws before pushing undo.
  test('group_rejects_non_contiguous', () async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([def('a'), def('b'), def('c')]),
    );

    controller.toggleSelect('a');
    controller.toggleSelect('c'); // b sits between them
    expect(controller.canGroup, isFalse);
    expect(() => controller.groupSelection(), throwsStateError);
    expect(controller.canUndo, isFalse); // rejected before any push
    expect(controller.tree.toDebugString(), 'def:a | def:b | def:c');
  });

  // 11. Ungroup targets the OUTERMOST selected group only: an inner group
  //     is unreachable while its parent holds it; once the outer group is
  //     dissolved the inner one is root-level and can be ungrouped too.
  test('ungroup_outermost_only', () async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([
        groupOf('g1', [def('a'), groupOf('g2', [def('b')])]),
      ]),
    );

    controller.selectOnly('g2'); // inner group — unreachable by design
    expect(controller.canUngroup, isFalse);
    expect(() => controller.ungroupSelection(), throwsStateError);
    expect(controller.canUndo, isFalse); // rejected before any push

    controller.selectOnly('g1');
    expect(controller.canUngroup, isTrue);
    controller.ungroupSelection();
    expect(controller.tree.toDebugString(), 'def:a | group:g2[1]{def:b}');
    expect(controller.tree.parentOf('g2'), isNull); // g2 promoted to root
    expect(controller.selection, isEmpty);

    controller.selectOnly('g2'); // now root-level
    expect(controller.canUngroup, isTrue);
    controller.ungroupSelection();
    expect(controller.tree.toDebugString(), 'def:a | def:b');
  });

  // 12. setGroupRepeat rebuilds the group def in place (children kept),
  //     rejects repeat < 1 before pushing, and undoes back to the
  //     original count in one step.
  test('set_group_repeat_is_undoable', () async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([groupOf('g', [def('a'), def('b')])]),
    );

    expect(() => controller.setGroupRepeat('g', 0), throwsArgumentError);
    expect(controller.canUndo, isFalse); // validation throws before push

    controller.setGroupRepeat('g', 4);
    final group = controller.tree.nodeById('g') as GroupNode;
    expect(group.group.repeatCount, 4);
    expect(group.children.map((n) => n.id), ['a', 'b']); // children kept
    expect(controller.canUndo, isTrue);

    controller.undo();
    final restored = controller.tree.nodeById('g') as GroupNode;
    expect(restored.group.repeatCount, 1); // back to the original
    expect(controller.canUndo, isFalse);
  });

  // 13. Mixed selection {G1, b} with b INSIDE G1: only the topmost id is
  //     grouped — the fresh group wraps G1 itself, and since g1 is its only
  //     child the chain collapses into one group (repeat product, outer id).
  test('group_mixed_topmost_wins', () async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([groupOf('g1', [def('a'), def('b')])]),
    );

    controller.toggleSelect('g1');
    controller.toggleSelect('b'); // b sits inside g1
    expect(controller.canGroup, isTrue);

    final outer = controller.groupSelection();
    expect(outer, isNot('g1'));
    expect(
      controller.tree.toDebugString(),
      'group:$outer[1]{def:a | def:b}',
    );
    expect(controller.selection, isEmpty); // action rule: no selection
    expect(
      controller.tree.allIds,
      isNot(contains('g1')),
      reason: 'the collapsed chain absorbs g1 — its id no longer exists',
    );
  });

  // 14. Undo cap: 55 renames push 55 PRE-states ('start','n0',..,'n53');
  //     the cap keeps only the 50 most recent, dropping the five oldest
  //     ('start','n0'..'n3'). 50 undos walk back exactly to 'n4' (the state
  //     before rename('n5')), then the stack is dry — the 51st undo is a
  //     no-op.
  test('undo_cap_50_drops_oldest', () {
    controller.name = 'start'; // seed state; a direct write is not an op
    for (var i = 0; i < 55; i++) {
      controller.rename('n$i');
    }
    expect(controller.name, 'n54');
    expect(controller.canUndo, isTrue);

    for (var i = 0; i < 50; i++) {
      controller.undo();
    }
    expect(controller.name, 'n4');
    expect(controller.canUndo, isFalse);

    // 51st undo: no-op (name unchanged, stack still dry).
    controller.undo();
    expect(controller.name, 'n4');
    expect(controller.canUndo, isFalse);
  });

  // ── Tweaks #4: Alt+Up/Down block move ("gather") ──────────────────

  Future<EditorController> six() => buildEditor(
      IntervalTree([def('a'), def('b'), def('c'), def('d'), def('e'), def('f')]));

  test('block_move_single_row_steps_one', () async {
    controller = await six();
    expect(controller.moveBlockBy(1, 'b'), isTrue);
    expect(controller.tree.roots.map((n) => n.id),
        ['a', 'c', 'b', 'd', 'e', 'f']);
    expect(controller.moveBlockBy(-1, 'b'), isTrue);
    expect(controller.tree.roots.map((n) => n.id),
        ['a', 'b', 'c', 'd', 'e', 'f']);
  });

  test('block_move_gathers_noncontiguous_behind_focus', () async {
    controller = await six();
    controller.toggleSelect('a');
    controller.toggleSelect('c');
    // The TWEAKS.md example: selection {a, c}, focus e, Alt+Down —
    // the block steps past f and re-inserts contiguous above e.
    expect(controller.moveBlockBy(1, 'e'), isTrue);
    expect(controller.tree.roots.map((n) => n.id),
        ['b', 'd', 'f', 'a', 'c', 'e']);
  });

  test('block_move_blocked_edge_is_noop', () async {
    controller = await six();
    controller.toggleSelect('b');
    expect(controller.moveBlockBy(-1, 'a'), isFalse);
    expect(controller.moveBlockBy(1, 'f'), isFalse);
    expect(controller.tree.roots.map((n) => n.id),
        ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(controller.canUndo, isFalse);
  });

  test('block_move_is_one_undo_step', () async {
    controller = await six();
    controller.toggleSelect('a');
    controller.toggleSelect('c');
    controller.moveBlockBy(1, 'e');
    controller.undo();
    expect(controller.tree.roots.map((n) => n.id),
        ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(controller.canUndo, isFalse);
  });

  test('block_move_down_past_group_header_enters_group', () async {
    controller = await buildEditor(IntervalTree(
        [def('a'), groupOf('g', [def('b'), def('c')]), def('d')]));
    expect(controller.moveBlockBy(1, 'a'), isTrue);
    final g = controller.tree.nodeById('g') as GroupNode;
    expect(g.children.map((n) => n.id), ['a', 'b', 'c']);
    expect(controller.tree.roots.map((n) => n.id), ['g', 'd']);
  });

  test('block_move_up_past_group_header_exits_and_dissolves', () async {
    controller = await buildEditor(IntervalTree(
        [def('a'), groupOf('g', [def('b'), def('c')]), def('d')]));
    controller.toggleSelect('c');
    expect(controller.moveBlockBy(-1, 'b'), isTrue);
    // Both children leave — the emptied group dissolves.
    expect(controller.tree.roots.map((n) => n.id), ['a', 'b', 'c', 'd']);
  });

  test('block_move_repeat_keeps_block_together', () async {
    controller = await buildEditor(IntervalTree([
      def('a'), def('b'), def('c'), def('d'),
      def('e'), def('f'), def('g'), def('h'),
    ]));
    controller.toggleSelect('a');
    controller.toggleSelect('c');
    controller.moveBlockBy(1, 'e');
    expect(controller.tree.roots.map((n) => n.id),
        ['b', 'd', 'f', 'a', 'c', 'e', 'g', 'h']);
    controller.moveBlockBy(1, 'e');
    expect(controller.tree.roots.map((n) => n.id),
        ['b', 'd', 'f', 'g', 'a', 'c', 'e', 'h']);
  });

  test('block_move_dedupes_selected_descendants', () async {
    controller = await buildEditor(IntervalTree(
        [def('a'), groupOf('g', [def('b'), def('c')]), def('d')]));
    controller.toggleSelect('g');
    controller.toggleSelect('b'); // child of the selected group
    expect(controller.moveBlockBy(1, 'g'), isTrue);
    // g moves as its whole subtree; b rides along, not moved twice.
    expect(controller.tree.roots.map((n) => n.id), ['a', 'd', 'g']);
    final g = controller.tree.nodeById('g') as GroupNode;
    expect(g.children.map((n) => n.id), ['b', 'c']);
  });
}

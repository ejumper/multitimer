import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/editor_controller.dart';
import 'package:planner/editor_screen.dart';
import 'package:planner/interval_editor.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// EditorScreen widget tests (P4.1): bracket nesting depths, chip contents,
/// the color/label rows, the toolbar duplicate-undo-delete flow, the
/// drag-drop handler rules, commit vs discard, and the empty state — over
/// an in-memory drift store with the fixture tree
/// `[a 'break' 60s alert, G(g1, repeat 3){b 'Cards' 30s}]`.
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late Board board;
  late IntervalTimer timer;
  late EditorController controller;
  var doneCalls = 0;

  void doneSpy() => doneCalls++;

  IntervalTree fixtureTree() => IntervalTree([
    DefNode(
      IntervalDef(
        id: 'a',
        timerId: timer.id,
        name: 'break',
        color: '#4800ff',
        durationSeconds: 60,
        autoFinish: false,
        endAlertSoundFile: 'ding.mp3',
      ),
    ),
    GroupNode(
      GroupDef(id: 'g1', timerId: timer.id, repeatCount: 3),
      [
        DefNode(
          IntervalDef(
            id: 'b',
            timerId: timer.id,
            name: 'Cards',
            color: '#0055ff',
            durationSeconds: 30,
            autoFinish: false,
          ),
        ),
      ],
    ),
  ]);

  /// Compact def builder for the group/ungroup fixtures.
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

  /// Saves [tree] as the timer's definition and builds the editor
  /// controller over it (store and working copy start out identical).
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
    controller = await buildEditor(fixtureTree());
    doneCalls = 0;
  });

  tearDown(() async {
    controller.dispose();
    await store.close();
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          controller: controller,
          soundsDir: '/sounds',
          soundListing: () => const ['a.mp3'],
          player: RecordingPlayer(),
          onDone: doneSpy,
        ),
      ),
    );
  }

  // 1. Nesting depth 3 → three stacked bracket columns, each with its
  //    repeat-count badge rendered as text.
  testWidgets('bracket_rendering_nesting_depths', (tester) async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([
        GroupNode(GroupDef(id: 'g1', timerId: timer.id, repeatCount: 1), [
          GroupNode(GroupDef(id: 'g2', timerId: timer.id, repeatCount: 2), [
            GroupNode(
              GroupDef(id: 'g3', timerId: timer.id, repeatCount: 3),
              [
                DefNode(
                  IntervalDef(
                    id: 'deep',
                    timerId: timer.id,
                    name: 'lap',
                    color: '#0055ff',
                    durationSeconds: 60,
                    autoFinish: false,
                  ),
                ),
              ],
            ),
          ]),
        ]),
      ]),
    );
    await pumpEditor(tester);

    for (final (id, count) in [('g1', '1'), ('g2', '2'), ('g3', '3')]) {
      final badge = find.byKey(Key('repeat-$id'));
      expect(badge, findsOneWidget, reason: 'missing bracket for $id');
      expect(
        find.descendant(of: badge, matching: find.text(count)),
        findsOneWidget,
        reason: 'missing repeat count $count on $id',
      );
    }
  });

  // 2. Chips show label + formatted duration + alert subtitle; no "N."
  //    numbering on chips (that's the board overlay's format).
  testWidgets('chip_rows_show_label_duration_alert', (tester) async {
    await pumpEditor(tester);

    final chipA = find.byKey(const Key('chip-a'));
    expect(find.descendant(of: chipA, matching: find.text('break')), findsOneWidget);
    expect(find.descendant(of: chipA, matching: find.text('1m')), findsOneWidget); // 60s
    expect(find.descendant(of: chipA, matching: find.text('ding.mp3')), findsOneWidget);

    final chipB = find.byKey(const Key('chip-b'));
    expect(find.descendant(of: chipB, matching: find.text('Cards')), findsOneWidget);
    expect(find.descendant(of: chipB, matching: find.text('30s')), findsOneWidget);
    expect(find.descendant(of: chipB, matching: find.text('No end alert')), findsOneWidget);

    expect(find.text('1. break'), findsNothing);
  });

  // 3. Tapping a swatch updates the working-copy color.
  testWidgets('color_row_selects_and_updates', (tester) async {
    await pumpEditor(tester);
    expect(controller.color, '#0055ff'); // seeded from the timer

    await tester.tap(find.byKey(const Key('swatch-#ff00b1')));
    await tester.pump();

    expect(controller.color, '#ff00b1');
  });

  // 4. Typing into the label field renames the working copy.
  testWidgets('label_field_updates_name', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byKey(const Key('label-field')), 'Evening');
    expect(controller.name, 'Evening');
  });

  // 5. Toolbar flow: select → duplicate (tree grows) → undo (back) →
  //    delete (selection removed).
  testWidgets('toolbar_duplicate_delete_undo', (tester) async {
    await pumpEditor(tester);
    final before = controller.tree.allIds.length; // a, g1, b

    // Nothing selected → duplicate/delete disabled.
    expect(
      tester.widget<IconButton>(find.byKey(const Key('tool-duplicate'))).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('select-a')));
    await tester.pump();
    expect(controller.selection, {'a'});
    expect(
      tester.widget<IconButton>(find.byKey(const Key('tool-duplicate'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('tool-duplicate')));
    await tester.pump();
    expect(controller.tree.roots.length, 3); // a, a', group — 3 top-level-ish
    expect(controller.tree.allIds.length, before + 1); // one copy of chip a
    expect(controller.tree.roots[1].id, isNot('a')); // fresh id on the copy

    await tester.tap(find.byKey(const Key('tool-undo')));
    await tester.pump();
    expect(controller.tree.roots.length, 2); // back to 2
    expect(controller.tree.allIds.length, before);
    expect(controller.selection, isEmpty); // action rule: undo clears too

    await tester.tap(find.byKey(const Key('select-a'))); // re-select
    await tester.pump();
    await tester.tap(find.byKey(const Key('tool-delete')));
    await tester.pump();
    expect(controller.tree.allIds, ['g1', 'b']); // chip a deleted
    expect(controller.selection, isEmpty);
    expect(controller.hasSelection, isFalse);
  });

  // 6. Drop rules: dropping chip a onto chip b moves a into b's parent
  //    (g1) at b's index → G{a, b}; the screen rebuilds accordingly.
  /// Gesture drag with a LAZILY measured aim point: the list reflows while
  /// dragging (the lifted row collapses, the slot gap opens), so the aim
  /// must be measured on the live layout after the drag has started.
  Future<void> dragRowToAiming(
    WidgetTester tester,
    String rowKey,
    Offset Function() aim,
  ) async {
    final start = tester.getCenter(find.byKey(Key(rowKey)));
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveTo(start + const Offset(0, 20)); // past touch slop
    await tester.pump(); // drag started; layout settled
    final a = aim();
    await gesture.moveTo(a);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  /// Gesture drag: press [rowKey]'s center, move past touch slop (starts
  /// the drag), then move to [to] (updates the slot) and release.
  Future<void> dragRowTo(WidgetTester tester, String rowKey, Offset to) async {
    final start = tester.getCenter(find.byKey(Key(rowKey)));
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveTo(start + const Offset(0, 20)); // past touch slop
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  // 6. Drag-drop: movement past slop lifts the whole row; the list reflows
  //    live with a slot marker; the drop lands at the slot (into groups,
  //    out to root, group-as-unit); one drag = one undo step and clears the
  //    selection; same-position drops are harmless no-ops.
  testWidgets('drag_drop_moves_into_group', (tester) async {
    await pumpEditor(tester);

    final bTop = tester.getTopLeft(find.byKey(const Key('chip-b'))).dy;
    await dragRowTo(
      tester,
      'chip-a',
      Offset(tester.getCenter(find.byKey(const Key('chip-a'))).dx, bTop + 8),
    );

    expect(controller.tree.toDebugString(), 'group:g1[3]{def:a | def:b}');
    expect(
      find.descendant(
        of: find.byKey(const Key('row-g1')),
        matching: find.byKey(const Key('chip-a')),
      ),
      findsOneWidget,
      reason: 'screen should rebuild with a inside the group row',
    );
  });

  testWidgets('drag_slot_gap_shows_during_drag', (tester) async {
    await pumpEditor(tester);

    final start = tester.getCenter(find.byKey(const Key('chip-a')));
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveTo(start + const Offset(0, 20));
    await tester.pump();
    expect(
      find.byKey(const Key('drag-slot')),
      findsOneWidget,
      reason: 'a live slot marker opens while dragging',
    );
    await gesture.moveTo(start + const Offset(0, 60));
    await tester.pump();
    expect(find.byKey(const Key('drag-slot')), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(
      find.byKey(const Key('drag-slot')),
      findsNothing,
      reason: 'the marker disappears on release',
    );
  });

  testWidgets('drag_out_of_group_dissolves_and_reorders', (tester) async {
    await pumpEditor(tester);
    controller.toggleSelect('a');
    await tester.pump();

    final aTop = tester.getTopLeft(find.byKey(const Key('chip-a'))).dy;
    final bX = tester.getCenter(find.byKey(const Key('chip-b'))).dx;
    await dragRowTo(tester, 'chip-b', Offset(bX, aTop - 2));

    // b lands before a at root; g1's emptied group dissolves (engine
    // "groups are never empty" invariant).
    expect(controller.tree.toDebugString(), 'def:b | def:a');
    expect(
      controller.selection,
      isEmpty,
      reason: 'a completed drag clears the selection',
    );
    controller.undo();
    expect(
      controller.tree.toDebugString(),
      'def:a | group:g1[3]{def:b}',
      reason: 'one drag = one undo step restores the whole move',
    );
  });

  testWidgets('drag_group_moves_subtree_as_unit', (tester) async {
    controller = await buildEditor(
      IntervalTree([
        GroupNode(
          GroupDef(id: 'g1', timerId: timer.id, repeatCount: 2),
          [def('b'), def('c')],
        ),
        def('a'),
      ]),
    );
    await pumpEditor(tester);

    final aBottom = tester.getBottomLeft(find.byKey(const Key('chip-a'))).dy;
    final bracketX = tester.getCenter(find.byKey(const Key('bracket-g1'))).dx;
    await dragRowTo(tester, 'bracket-g1', Offset(bracketX, aBottom + 4));

    expect(
      controller.tree.toDebugString(),
      'def:a | group:g1[2]{def:b | def:c}',
      reason: 'the group lands after a with its children intact and ordered',
    );
  });

  testWidgets('drag_drop_to_same_position_is_noop', (tester) async {
    await pumpEditor(tester);
    final before = controller.tree.toDebugString();

    // Drag the group slightly (pointer stays over its own rows) and release
    // — the only legal slot is its current position; nothing changes.
    final bCenter = tester.getCenter(find.byKey(const Key('chip-b')));
    await dragRowTo(tester, 'bracket-g1', bCenter + const Offset(0, 4));

    expect(controller.tree.toDebugString(), before);
  });

  testWidgets('drag_clears_selection', (tester) async {
    await pumpEditor(tester);
    controller.toggleSelect('a');
    await tester.pump();
    expect(controller.selection, isNotEmpty);

    final aX = tester.getCenter(find.byKey(const Key('chip-a'))).dx;
    final bBottom = tester.getBottomLeft(find.byKey(const Key('chip-b'))).dy;
    await dragRowTo(tester, 'chip-a', Offset(aX, bBottom + 6));

    expect(controller.tree.toDebugString(), 'group:g1[3]{def:b} | def:a');
    expect(controller.selection, isEmpty);
  });

  testWidgets('two_simultaneous_drags_are_safe', (tester) async {
    await pumpEditor(tester);
    final a = tester.getCenter(find.byKey(const Key('chip-a')));
    final b = tester.getCenter(find.byKey(const Key('chip-b')));

    // Two pointers at once (trackpad palm + finger): the second drag takes
    // over — the first drag's floating overlay entry must be cleaned up,
    // not leaked (a leaked entry rebuilds with no active drag and throws
    // "Null check operator" every frame — the "went haywire" bug).
    final g1 = await tester.startGesture(a);
    await tester.pump();
    await g1.moveTo(a + const Offset(0, 20));
    await tester.pump();
    final g2 = await tester.startGesture(b);
    await tester.pump();
    await g2.moveTo(b + const Offset(0, 20)); // takes over the drag
    await tester.pump();
    expect(find.byKey(const Key('drag-slot')), findsOneWidget);

    await g2.up(); // the takeover drag commits…
    await tester.pump();
    await g1.up(); // …the stale end must be a harmless no-op
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drag-slot')), findsNothing);
    expect(
      controller.tree.toDebugString(),
      'def:a | def:b',
      reason: 'exactly ONE move (b out of g1; emptied group dissolves)',
    );

    // A fresh drag forces the overlay to rebuild every entry — with a
    // leaked entry from the two-pointer episode this is where the
    // "Null check operator" crash surfaces.
    await dragRowTo(tester, 'chip-a', a + const Offset(0, 30));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('drag-slot')), findsNothing);
  });

  testWidgets('stale_recognizer_end_does_not_commit_active_drag',
      (tester) async {
    await pumpEditor(tester);
    final a = tester.getCenter(find.byKey(const Key('chip-a')));
    final b = tester.getCenter(find.byKey(const Key('chip-b')));

    final g1 = await tester.startGesture(a);
    await tester.pump();
    await g1.moveTo(a + const Offset(0, 20));
    await tester.pump();
    final g2 = await tester.startGesture(b);
    await tester.pump();
    await g2.moveTo(b + const Offset(0, 20)); // takes over
    await tester.pump();

    await g1.up(); // the STALE recognizer's end must neither commit nor clear
    await tester.pump();
    expect(
      find.byKey(const Key('drag-slot')),
      findsOneWidget,
      reason: 'the active drag survives the stale recognizer ending',
    );
    await g2.up();
    await tester.pumpAndSettle();
    expect(
      controller.tree.toDebugString(),
      'def:a | def:b',
      reason: 'exactly ONE move — the stale end did not double-commit',
    );
    expect(tester.takeException(), isNull);
  });

  /// These fixtures run past the default 600px test window — without a
  /// taller surface the deep rows are off-screen and gestures miss them.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// [m, g1{ g2{b, c}, d }, x] — the legal shape with a coincident top
  /// edge (g1's first child is the group g2, so g1's top edge IS g2's top
  /// edge). Used to pin the X-depth disambiguation of edge slots.
  IntervalTree nestedEdgeTree() => IntervalTree([
    def('m'),
    GroupNode(
      GroupDef(id: 'g1', timerId: timer.id, repeatCount: 1),
      [
        GroupNode(
          GroupDef(id: 'g2', timerId: timer.id, repeatCount: 1),
          [def('b'), def('c')],
        ),
        def('d'),
      ],
    ),
    def('x'),
  ]);

  /// Aim: just above g2's top-left corner (the coincident edge), with the
  /// pointer's X in the given zone: content column (inner), g2's bracket
  /// column (outer), left of the block (outside all).
  Offset Function() edgeAim(WidgetTester tester, double Function(Rect g2) x) {
    return () {
      final g2 = tester.getRect(find.byKey(const Key('row-g2')));
      return Offset(x(g2), g2.top - 2);
    };
  }

  // Edge-slot level follows the pointer's X: content column = the inner
  // group, bracket column = the outer group, left of that = outside all.
  Future<void> pressWithCtrl(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }

  // Keyboard sections (acceptance): Tab cycles top/color/name/buttons/
  // intervals; Ctrl+Home/End jump; Enter acts; Escape = Done.
  testWidgets('keyboard_editor_sections', (tester) async {
    await pumpEditor(tester);

    // Tab once -> the color section; Enter picks the first swatch.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.color, '#e2e2e2');

    // Ctrl+End -> the intervals section; Enter toggles the first circle.
    await pressWithCtrl(tester, LogicalKeyboardKey.end);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.selection, contains('a'));

    // Escape = Done: commits and closes the editor.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editor-done')), findsNothing);
    expect(controller.canUndo, isTrue); // the color/selection edits landed
  });

  // Keyboard grid over the nested intervals: the three vertical tracks
  // (selectors / group columns / rectangles) + reading-order horizontal.
  testWidgets('keyboard_editor_grid_navigation', (tester) async {
    controller.dispose();
    controller = await buildEditor(nestedEdgeTree());
    await pumpEditor(tester);

    await pressWithCtrl(tester, LogicalKeyboardKey.end); // intervals section
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // circle m
    await tester.pump();
    expect(controller.selection, contains('m'));

    // Down the SELECTOR track -> g1's circle; Right -> g1's group column.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // group column
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('repeat-modal')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    // End -> the last cell (x's rectangle); Enter opens x's editor.
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ie-back')), findsOneWidget);
  });

  // Editor shortcuts (acceptance): Ctrl+Z/C/N/Delete.
  testWidgets('keyboard_editor_shortcuts', (tester) async {
    await pumpEditor(tester);

    // Ctrl+N opens the interval editor; Shift+Escape? no — close via back.
    await pressWithCtrl(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ie-back')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ie-back')));
    await tester.pumpAndSettle();

    // Focus a chip cell and Ctrl+C duplicates that node.
    await pressWithCtrl(tester, LogicalKeyboardKey.end);
    await tester.pump();
    await pressWithCtrl(tester, LogicalKeyboardKey.keyC);
    await tester.pump();
    expect(controller.tree.roots.length, 3); // m? no — fixture [a, g1{b}]
    // Delete removes the focused node (the duplicate).
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(controller.tree.roots.length, 2);

    // Ctrl+Z undoes the delete.
    await pressWithCtrl(tester, LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(controller.tree.roots.length, 3);
  });

  testWidgets('edge_slot_content_column_targets_inner_group', (tester) async {
    useTallSurface(tester);
    controller = await buildEditor(nestedEdgeTree());
    await pumpEditor(tester);
    await dragRowToAiming(
      tester,
      'chip-x',
      edgeAim(tester, (g2) => g2.left + 64 + 8), // content column of g2
    );
    expect(
      controller.tree.toDebugString(),
      'def:m | group:g1[1]{group:g2[1]{def:x | def:b | def:c} | def:d}',
    );
  });

  testWidgets('edge_slot_bracket_column_targets_outer_group', (tester) async {
    useTallSurface(tester);
    controller = await buildEditor(nestedEdgeTree());
    await pumpEditor(tester);
    await dragRowToAiming(
      tester,
      'chip-x',
      edgeAim(tester, (g2) => g2.left + 8), // g2's bracket column
    );
    expect(
      controller.tree.toDebugString(),
      'def:m | group:g1[1]{def:x | group:g2[1]{def:b | def:c} | def:d}',
    );
  });

  testWidgets('edge_slot_left_column_targets_root', (tester) async {
    useTallSurface(tester);
    controller = await buildEditor(nestedEdgeTree());
    await pumpEditor(tester);
    await dragRowToAiming(
      tester,
      'chip-x',
      edgeAim(tester, (g2) => g2.left - 8), // left of the whole block
    );
    expect(
      controller.tree.toDebugString(),
      'def:m | def:x | group:g1[1]{group:g2[1]{def:b | def:c} | def:d}',
    );
  });

  testWidgets('drag_leaving_group_chain_collapses_with_product',
      (tester) async {
    useTallSurface(tester);
    // g1(3){ g2(2){b, c}, d } — moving d out leaves a single-group chain:
    // it collapses to one group with the product repeat (3×2=6), keeping
    // the outer group's id and the inner's children.
    controller = await buildEditor(
      IntervalTree([
        def('m'),
        GroupNode(
          GroupDef(id: 'g1', timerId: timer.id, repeatCount: 3),
          [
            GroupNode(
              GroupDef(id: 'g2', timerId: timer.id, repeatCount: 2),
              [def('b'), def('c')],
            ),
            def('d'),
          ],
        ),
      ]),
    );
    await pumpEditor(tester);

    final mTop = tester.getTopLeft(find.byKey(const Key('chip-m'))).dy;
    final dX = tester.getCenter(find.byKey(const Key('chip-d'))).dx;
    await dragRowTo(tester, 'chip-d', Offset(dX, mTop - 2));

    expect(
      controller.tree.toDebugString(),
      'def:d | def:m | group:g1[6]{def:b | def:c}',
    );
  });

  // 7. Done: commits the working copy, fires onDone, and the store has
  //    the new name + an editor.commit event.
  testWidgets('done_commits_and_calls_ondone', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byKey(const Key('label-field')), 'Evening');
    await tester.tap(find.byKey(const Key('editor-done')));
    await tester.pumpAndSettle();

    expect(doneCalls, 1);
    final storedTimer = (await store.timersInBoard(board.id)).single;
    expect(storedTimer.name, 'Evening');
    final events = await store.events();
    expect(events.map((e) => e.kind), contains('editor.commit'));
  });

  // 8. ✕: reverts without committing — onDone never fires, the store is
  //    untouched (timer name, tree, and event log all unchanged).
  testWidgets('close_reverts_without_ondone', (tester) async {
    await pumpEditor(tester);
    final eventsBefore = (await store.events()).length;

    await tester.enterText(find.byKey(const Key('label-field')), 'Evening');
    await tester.tap(find.byKey(const Key('editor-close')));
    await tester.pumpAndSettle();

    expect(doneCalls, 0);
    final storedTimer = (await store.timersInBoard(board.id)).single;
    expect(storedTimer.name, 'Interval timer');
    expect((await store.events()).length, eventsBefore);
    expect(
      (await store.loadTree(timer.id)).toDebugString(),
      'def:a | group:g1[3]{def:b}',
    );
  });

  // 9. Empty tree: the hint shows and the add affordance pushes the
  //    real interval editor (P4.3).
  testWidgets('empty_state_hint_and_add_affordance', (tester) async {
    controller.dispose();
    controller = await buildEditor(const IntervalTree([]));
    await pumpEditor(tester);

    expect(find.byKey(const Key('empty-state')), findsOneWidget);
    expect(find.text('No intervals yet'), findsOneWidget);
    expect(find.byKey(const Key('chip-list')), findsNothing);

    await tester.tap(find.byKey(const Key('empty-add')));
    await tester.pumpAndSettle();
    expect(find.byType(IntervalEditorScreen), findsOneWidget);
    expect(find.byKey(const Key('ie-back')), findsOneWidget);
  });

  // 10. Group enablement mirrors canGroup: a contiguous sibling run
  //     ([a, b]) enables the button, a scattered one ([a, c] over
  //     [a, b, c]) leaves it disabled.
  testWidgets(
    'group_button_enabled_for_contiguous_and_disabled_otherwise',
    (tester) async {
      controller.dispose();
      controller = await buildEditor(
        IntervalTree([def('a'), def('b'), def('c')]),
      );
      await pumpEditor(tester);

      IconButton groupButton() =>
          tester.widget<IconButton>(find.byKey(const Key('tool-group')));

      expect(groupButton().onPressed, isNull); // nothing selected

      await tester.tap(find.byKey(const Key('select-a')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('select-b')));
      await tester.pump();
      expect(controller.selection, {'a', 'b'});
      expect(groupButton().onPressed, isNotNull); // contiguous siblings

      await tester.tap(find.byKey(const Key('select-a'))); // deselect a
      await tester.pump();
      await tester.tap(find.byKey(const Key('select-b'))); // deselect b
      await tester.pump();
      expect(controller.selection, isEmpty);
      expect(groupButton().onPressed, isNull);

      await tester.tap(find.byKey(const Key('select-a')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('select-c')));
      await tester.pump();
      expect(controller.selection, {'a', 'c'});
      expect(groupButton().onPressed, isNull); // b sits between them
    },
  );

  // 11. Toolbar Group on a single chip: the stepper auto-opens at 1, three
  //     + taps take it to 4, OK lands the count on the fresh group's badge
  //     and dismisses the modal (chip a is now wrapped).
  testWidgets('single_interval_group_repeat_modal_auto_opens', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.byKey(const Key('select-a')));
    await tester.pump();
    expect(controller.canGroup, isTrue);

    await tester.tap(find.byKey(const Key('tool-group')));
    await tester.pumpAndSettle();

    final modal = find.byKey(const Key('repeat-modal'));
    expect(modal, findsOneWidget);
    expect(
      find.descendant(of: modal, matching: find.text('1')),
      findsOneWidget,
      reason: 'stepper should open at the default count 1',
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('repeat-plus')));
      await tester.pump();
    }
    expect(
      find.descendant(of: modal, matching: find.text('4')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('repeat-value'))).data,
      '4',
    );

    await tester.tap(find.byKey(const Key('repeat-ok')));
    await tester.pumpAndSettle();

    expect(modal, findsNothing);
    final group = controller.tree.roots
        .whereType<GroupNode>()
        .firstWhere((n) => n.children.any((c) => c.id == 'a'));
    expect(group.group.repeatCount, 4);
    expect(
      find.descendant(
        of: find.byKey(Key('repeat-${group.id}')),
        matching: find.text('4'),
      ),
      findsOneWidget,
      reason: 'new group badge should carry the confirmed count',
    );
    expect(find.byKey(const Key('chip-a')), findsOneWidget);
  });

  // 12. Tapping a root-level group's bracket reopens the stepper seeded
  //     with its current count (3); − takes it to 2 and OK updates the
  //     badge in place.
  testWidgets('bracket_bar_reopens_repeat_modal', (tester) async {
    await pumpEditor(tester); // fixture: root group g1, repeat 3

    await tester.tap(find.byKey(const Key('bracket-g1')));
    await tester.pumpAndSettle();

    final modal = find.byKey(const Key('repeat-modal'));
    expect(modal, findsOneWidget);
    expect(controller.selection, {'g1'}); // selectOnly, no undo step
    expect(
      find.descendant(of: modal, matching: find.text('3')),
      findsOneWidget,
      reason: 'stepper should open at the current count 3',
    );

    await tester.tap(find.byKey(const Key('repeat-minus')));
    await tester.pump();
    expect(
      find.descendant(of: modal, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('repeat-ok')));
    await tester.pumpAndSettle();

    expect(modal, findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('repeat-g1')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      (controller.tree.nodeById('g1') as GroupNode).group.repeatCount,
      2,
    );
  });

  // 13. Nested groups are REACHABLE (acceptance: the outermost-only rule
  //     was a misreading): tapping an inner bracket opens ITS repeat
  //     stepper — the "nested group repeats 2× inside a parent that
  //     repeats 3×" case.
  testWidgets('inner_bracket_tap_opens_repeat_modal', (tester) async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([
        GroupNode(GroupDef(id: 'g1', timerId: timer.id, repeatCount: 3), [
          GroupNode(GroupDef(id: 'g2', timerId: timer.id, repeatCount: 2), [
            def('x', name: 'lap'),
          ]),
        ]),
      ]),
    );
    await pumpEditor(tester);

    await tester.tap(find.byKey(const Key('bracket-g2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('repeat-modal')), findsOneWidget);
    // Bump the inner repeat 2 -> 4 and confirm.
    await tester.tap(find.byKey(const Key('repeat-plus')));
    await tester.tap(find.byKey(const Key('repeat-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('repeat-ok')));
    await tester.pumpAndSettle();

    // The INNER group's repeat changed; the outer's is untouched.
    expect(controller.tree.toDebugString(), 'group:g1[3]{group:g2[4]{def:x}}');
  });

  // 14. Ungroup toolbar flow: select the root group → button enables →
  //     one tap dissolves exactly that group — chips promoted to the roots,
  //     bracket and badge gone, button disabled again (selection cleared).
  testWidgets('ungroup_toolbar_flow', (tester) async {
    await pumpEditor(tester); // fixture: a + root group g1{b}

    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('tool-ungroup')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('select-g1')));
    await tester.pump();
    expect(controller.selection, {'g1'});
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('tool-ungroup')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('tool-ungroup')));
    await tester.pump();

    expect(controller.tree.toDebugString(), 'def:a | def:b');
    expect(find.byKey(const Key('chip-a')), findsOneWidget);
    expect(find.byKey(const Key('chip-b')), findsOneWidget); // promoted
    expect(find.byKey(const Key('bracket-g1')), findsNothing);
    expect(find.byKey(const Key('repeat-g1')), findsNothing); // gone
    expect(controller.selection, isEmpty);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('tool-ungroup')))
          .onPressed,
      isNull,
    );
  });
}

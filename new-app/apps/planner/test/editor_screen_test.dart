import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/editor_controller.dart';
import 'package:planner/editor_screen.dart';
import 'package:planner/interval_editor_placeholder.dart';
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
      MaterialApp(home: EditorScreen(controller: controller, onDone: doneSpy)),
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
    expect(controller.selection, {'a'}); // snapshot selection restored

    await tester.tap(find.byKey(const Key('tool-delete')));
    await tester.pump();
    expect(controller.tree.allIds, ['g1', 'b']); // chip a deleted
    expect(controller.selection, isEmpty);
    expect(controller.hasSelection, isFalse);
  });

  // 6. Drop rules: dropping chip a onto chip b moves a into b's parent
  //    (g1) at b's index → G{a, b}; the screen rebuilds accordingly.
  testWidgets('drag_drop_moves_into_group', (tester) async {
    await pumpEditor(tester);

    final target = tester.widget<DragTarget<String>>(
      find.byKey(const Key('drop-b')),
    );
    target.onAcceptWithDetails!(
      DragTargetDetails<String>(data: 'a', offset: Offset.zero),
    );
    await tester.pump();

    expect(controller.tree.toDebugString(), 'group:g1[3]{def:a | def:b}');
    expect(
      find.descendant(
        of: find.byKey(const Key('drop-g1')),
        matching: find.byKey(const Key('chip-a')),
      ),
      findsOneWidget,
      reason: 'screen should rebuild with a inside the group row',
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
  //    interval editor stub (P4.3 replaces it).
  testWidgets('empty_state_hint_and_add_affordance', (tester) async {
    controller.dispose();
    controller = await buildEditor(const IntervalTree([]));
    await pumpEditor(tester);

    expect(find.byKey(const Key('empty-state')), findsOneWidget);
    expect(find.text('No intervals yet'), findsOneWidget);
    expect(find.byKey(const Key('chip-list')), findsNothing);

    await tester.tap(find.byKey(const Key('empty-add')));
    await tester.pumpAndSettle();
    expect(find.byType(IntervalEditorPlaceholderScreen), findsOneWidget);
    expect(find.byKey(const Key('interval-editor-placeholder')), findsOneWidget);
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

  // 13. Inner groups stay unreachable: over [G1{G2{def}}], tapping G2's
  //     bracket does NOTHING — no modal opens and the selection is
  //     untouched (only outermost groups respond; MultiTimer mirroring).
  testWidgets('inner_bracket_tap_ignored', (tester) async {
    controller.dispose();
    controller = await buildEditor(
      IntervalTree([
        GroupNode(GroupDef(id: 'g1', timerId: timer.id, repeatCount: 1), [
          GroupNode(GroupDef(id: 'g2', timerId: timer.id, repeatCount: 2), [
            def('x', name: 'lap'),
          ]),
        ]),
      ]),
    );
    await pumpEditor(tester);

    await tester.tap(find.byKey(const Key('bracket-g2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('repeat-modal')), findsNothing);
    expect(controller.selection, isEmpty);
    expect(controller.canUndo, isFalse);
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

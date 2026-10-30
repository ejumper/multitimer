import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/editor_controller.dart';
import 'package:planner/interval_editor.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// IntervalEditorScreen widget tests (P4.3): the back-commit rules
/// (name-only → coerced 60s default, duration-only → unnamed, both, neither
/// → cancel), the existing-interval revert/replace rules incl. exactly one
/// undo step, and the create-mode first-alphabetical default alert — over
/// an in-memory drift store on a fixed clock with the fixture def
/// `a 'break' 60s manual ding.mp3`.
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late Board board;
  late IntervalTimer timer;
  late EditorController controller;
  late RecordingPlayer player;

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
  ]);

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
    player = RecordingPlayer();
  });

  tearDown(() async {
    controller.dispose();
    await store.close();
  });

  /// Pumps the editor over the fixture tree; [defId] selects EDIT mode
  /// (null = CREATE), [soundListing] overrides the alert-sounds listing.
  Future<void> pumpEditor(
    WidgetTester tester, {
    String? defId,
    List<String> Function()? soundListing,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IntervalEditorScreen(
          controller: controller,
          defId: defId,
          soundsDir: '/sounds',
          soundListing: soundListing ?? () => const ['alpha.mp3', 'beta.mp3'],
          player: player,
        ),
      ),
    );
  }

  /// The committed def behind [id] in the working tree.
  IntervalDef defOf(String id) => (controller.tree.nodeById(id) as DefNode).def;

  // 4. Name-only create: back commits the label with the coerced 60s
  //    default (IntervalDef requires duration > 0).
  testWidgets(
    'commit_rule_name_only_creates_with_default_duration',
    (tester) async {
      controller.dispose();
      controller = await buildEditor(const IntervalTree([])); // start empty
      await pumpEditor(tester);

      await tester.enterText(find.byKey(const Key('ie-label')), 'Focus');
      await tester.tap(find.byKey(const Key('ie-back')));
      await tester.pumpAndSettle();

      expect(find.byType(IntervalEditorScreen), findsNothing); // popped
      expect(controller.tree.allIds.length, 1);
      final def = (controller.tree.roots.single as DefNode).def;
      expect(def.name, 'Focus');
      expect(def.durationSeconds, 60);
    },
  );

  // 5. Duration-only create: boxes 0/05/00 → a 300s interval with no
  //    label (blank label is stored as null, not '').
  testWidgets('commit_rule_duration_only_creates', (tester) async {
    controller.dispose();
    controller = await buildEditor(const IntervalTree([]));
    await pumpEditor(tester);

    await tester.enterText(find.byKey(const Key('ie-hr')), '0');
    await tester.enterText(find.byKey(const Key('ie-min')), '5');
    await tester.enterText(find.byKey(const Key('ie-sec')), '0');
    await tester.tap(find.byKey(const Key('ie-back')));
    await tester.pumpAndSettle();

    expect(controller.tree.allIds.length, 1);
    final def = (controller.tree.roots.single as DefNode).def;
    expect(def.name, isNull);
    expect(def.durationSeconds, 300);
  });

  // 6. Both entered → both committed: label + exact 1m30s = 90s.
  testWidgets('commit_rule_both_creates', (tester) async {
    controller.dispose();
    controller = await buildEditor(const IntervalTree([]));
    await pumpEditor(tester);

    await tester.enterText(find.byKey(const Key('ie-label')), 'Lap');
    await tester.enterText(find.byKey(const Key('ie-min')), '1');
    await tester.enterText(find.byKey(const Key('ie-sec')), '30');
    await tester.tap(find.byKey(const Key('ie-back')));
    await tester.pumpAndSettle();

    expect(controller.tree.allIds.length, 1);
    final def = (controller.tree.roots.single as DefNode).def;
    expect(def.name, 'Lap');
    expect(def.durationSeconds, 90);
  });

  // 7. Neither entered → back on a fresh create is a CANCEL: the tree is
  //    untouched and no undo step lands.
  testWidgets('commit_rule_neither_cancels', (tester) async {
    controller.dispose();
    controller = await buildEditor(const IntervalTree([]));
    await pumpEditor(tester);

    await tester.tap(find.byKey(const Key('ie-back')));
    await tester.pumpAndSettle();

    expect(controller.tree.allIds, isEmpty);
    expect(controller.canUndo, isFalse);
  });

  // 8. The revert rule: blanking BOTH label and boxes on an existing
  //    def keeps it as it was ('break' / 60s) — the controller is not
  //    touched, so no undo step is pushed either.
  testWidgets('existing_interval_cannot_be_emptied', (tester) async {
    await pumpEditor(tester, defId: 'a'); // break / 60s

    await tester.enterText(find.byKey(const Key('ie-label')), '');
    await tester.enterText(find.byKey(const Key('ie-hr')), '');
    await tester.enterText(find.byKey(const Key('ie-min')), '');
    await tester.enterText(find.byKey(const Key('ie-sec')), '');
    await tester.tap(find.byKey(const Key('ie-back')));
    await tester.pumpAndSettle();

    final def = defOf('a');
    expect(def.name, 'break'); // kept — revert touches nothing
    expect(def.durationSeconds, 60);
    expect(controller.canUndo, isFalse);
  });

  // 9. A real edit commits via ONE replaceDef undo step (label, duration,
  //    auto-finish, alert — color untouched); undo restores the original
  //    def in one step. The alert is swapped through the selector.
  testWidgets('existing_interval_edit_updates', (tester) async {
    await pumpEditor(tester, defId: 'a'); // break / 60s / manual / ding

    await tester.enterText(find.byKey(const Key('ie-label')), 'Lunch');
    await tester.enterText(find.byKey(const Key('ie-min')), '0');
    await tester.enterText(find.byKey(const Key('ie-sec')), '30');
    await tester.tap(find.byKey(const Key('ie-autofinish')));
    await tester.pump();

    // Swap the end alert through the selector and come back.
    await tester.tap(find.byKey(const Key('ie-alert-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('as-row-alpha.mp3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('as-back')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ie-back')));
    await tester.pumpAndSettle();

    final def = defOf('a');
    expect(def.name, 'Lunch');
    expect(def.durationSeconds, 30);
    expect(def.autoFinish, isTrue);
    expect(def.endAlertSoundFile, 'alpha.mp3');
    expect(def.color, '#4800ff'); // no swatch was tapped

    // Exactly one undo step → back to the original def.
    expect(controller.canUndo, isTrue);
    controller.undo();
    final restored = defOf('a');
    expect(restored.name, 'break');
    expect(restored.durationSeconds, 60);
    expect(restored.autoFinish, isFalse);
    expect(restored.endAlertSoundFile, 'ding.mp3');
  });

  // 10. CREATE-mode default alert = first file alphabetically — the
  //     listing is deliberately unsorted, so 'alpha.mp3' must win and
  //     land on the committed def.
  testWidgets('new_interval_default_alert_first_alphabetical', (tester) async {
    controller.dispose();
    controller = await buildEditor(const IntervalTree([]));
    await pumpEditor(
      tester,
      soundListing: () => const ['beta.mp3', 'alpha.mp3'],
    );

    await tester.enterText(find.byKey(const Key('ie-label')), 'Chime');
    await tester.tap(find.byKey(const Key('ie-back')));
    await tester.pumpAndSettle();

    final def = (controller.tree.roots.single as DefNode).def;
    expect(def.endAlertSoundFile, 'alpha.mp3');
  });

  // ── Tweaks batch 1 (TWEAKS.md #1/#2) ──────────────────────────────

  // #1: the editor opens with the name field focused.
  testWidgets('tweaks_opens_with_name_field_focused', (tester) async {
    await pumpEditor(tester, defId: 'a');
    await tester.pump(); // the post-frame name focus
    final field =
        tester.widget<TextField>(find.byKey(const Key('ie-label')));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  // #2: the name field is not a trap — Tab moves focus out of it, and
  // Escape commits + goes back even mid-edit.
  testWidgets('tweaks_name_field_tab_and_escape_are_not_trapped',
      (tester) async {
    await pumpEditor(tester, defId: 'a');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('ie-label')), 'Focus');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final field =
        tester.widget<TextField>(find.byKey(const Key('ie-label')));
    expect(field.focusNode!.hasFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(defOf('a').name, 'Focus');
  });
}

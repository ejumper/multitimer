import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/app_controller.dart';
import 'package:planner/board_screen.dart';
import 'package:planner_engine/planner_engine.dart';

import 'fakes.dart';

/// Navigation shell + Library widget tests (v2 P3.1/P3.2).
///
/// Pinned here: the board's main bar — four buttons in order, Calendar
/// (P4.2) + Library live · open/close the Library (home) · plan-row meta (item
/// count for all-Open plans vs total duration, mixed fixtures) · the
/// created/modified row date · new-list lands on top of the CURRENT
/// folder (root fallback) and focuses its rename · delete mode → confirm
/// deletes · folder create/rename (right-click)/delete (confirmed
/// cascade) · drag reorder within a folder · a plan row opens its own
/// board bound to that timer (back → Library, home → board root) ·
/// save-to-folder (right-click on the board's Library button) copies into
/// the chosen folder with completion marks cleared.
///
/// Fixtures (saved BEFORE init) — dates derive from [t0] through the
/// same local conversion the row uses ([dayOf]):
/// - root: `Interval timer` (the v1 board timer, one 60s interval carrying
///   a completion mark — save-to-folder's source), `Weekend` (mixed: 120s
///   + Open), `Night shift` (created at t0, renamed a day later →
///   modified stamp),
/// - folder Errands: `Chores` (3 Open → count), `Workout` (60s + 30s →
///   total duration),
/// - folder Routines: empty.
///
/// The board's 1 Hz ticker and the hold pulse hang pumpAndSettle — every
/// pump here is bounded through [settle] (`tester.pump()` [+ 300ms]).
void main() {
  final t0 = DateTime.utc(2026, 3, 1, 8);

  late FixedClock clock;
  late PlannerDb db;
  late DriftStore store;
  late AppController controller;
  late Folder errands;
  late Folder routines;
  late IntervalTimer workout;
  late IntervalTimer chores;
  late IntervalTimer weekend;
  late IntervalTimer shift;

  /// The same local-time date conversion the plan row renders.
  String dayOf(DateTime t) =>
      DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch)
          .toIso8601String()
          .substring(0, 10);

  Future<void> buildFixture() async {
    clock = FixedClock(t0);
    db = PlannerDb(NativeDatabase.memory());
    store = DriftStore(db, clock);

    final board = await store.createBoard('My Board');

    // The v1 timer: a folder-less root plan AND save-to-folder's source —
    // its single interval carries a completion mark.
    final home = await store.createTimer(
      boardId: board.id,
      name: 'Interval timer',
      color: '#0055ff',
    );
    await store.saveTree(
      home.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'a',
            timerId: home.id,
            name: 'Warmup',
            color: '#0055ff',
            durationSeconds: 60,
            autoFinish: false,
            completed: true,
          ),
        ),
      ]),
      eventKind: 'tree.save',
    );

    errands = await store.createFolder('Errands');
    routines = await store.createFolder('Routines');

    // Created in reverse of display order: create lands on top, so
    // Workout first leaves [Chores, Workout] in the folder.
    workout = await store.createTimer(
      boardId: board.id,
      name: 'Workout',
      color: '#00ad6b',
      folderId: errands.id,
    );
    await store.saveTree(
      workout.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'w1',
            timerId: workout.id,
            name: 'Squat',
            color: '#00ad6b',
            durationSeconds: 60,
            autoFinish: true,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'w2',
            timerId: workout.id,
            name: 'Cardio',
            color: '#00ad6b',
            durationSeconds: 30,
            autoFinish: true,
          ),
        ),
      ]),
      eventKind: 'tree.save',
    );

    chores = await store.createTimer(
      boardId: board.id,
      name: 'Chores',
      color: '#ff00b1',
      folderId: errands.id,
    );
    await store.saveTree(
      chores.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'o1',
            timerId: chores.id,
            name: 'Dishes',
            color: '#ff00b1',
            durationSeconds: null, // Open
            autoFinish: false,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'o2',
            timerId: chores.id,
            name: 'Trash',
            color: '#ff00b1',
            durationSeconds: null, // Open
            autoFinish: false,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'o3',
            timerId: chores.id,
            name: 'Sweep',
            color: '#ff00b1',
            durationSeconds: null, // Open
            autoFinish: false,
          ),
        ),
      ]),
      eventKind: 'tree.save',
    );

    weekend = await store.createTimer(
      boardId: board.id,
      name: 'Weekend',
      color: '#b8ff00',
    );
    await store.saveTree(
      weekend.id,
      IntervalTree([
        DefNode(
          IntervalDef(
            id: 'm1',
            timerId: weekend.id,
            name: 'Hike',
            color: '#b8ff00',
            durationSeconds: 120,
            autoFinish: true,
          ),
        ),
        DefNode(
          IntervalDef(
            id: 'm2',
            timerId: weekend.id,
            name: 'Snacks',
            color: '#b8ff00',
            durationSeconds: null, // Open — mixed plan → duration branch
            autoFinish: false,
          ),
        ),
      ]),
      eventKind: 'tree.save',
    );

    shift = await store.createTimer(
      boardId: board.id,
      name: 'Shift',
      color: '#4800ff',
    );
    clock.current = t0.add(const Duration(days: 1));
    await store.updateTimer(shift.id, name: 'Night shift');
    clock.current = t0;

    controller = AppController(
      store: store,
      clock: clock,
      notifier: RecordingNotifier(),
      player: RecordingPlayer(),
      soundsDir: '/sounds',
      soundListing: () => const [],
    );
    await controller.init();
  }

  setUp(buildFixture);

  /// Bounded settle — the ticker/pulse hang pumpAndSettle. Two rounds of
  /// `pump()` + 300ms cover route transitions (150ms) and the store's
  /// async chains between frames.
  Future<void> settle(WidgetTester tester) async {
    // Generous rounds: the store's drift chains (delete + reload, the
    // async init/push seam) resolve over several microtask hops.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> pumpBoard(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: BoardScreen(controller)));
    await tester.pump();
  }

  Future<void> openLibrary(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('bar-library')));
    await settle(tester);
    expect(find.byKey(const Key('library-page')), findsOneWidget);
  }

  /// The folder's plans in display order (ascending sort index).
  Future<List<IntervalTimer>> folderPlans(String? folderId) async {
    final children =
        (await store.timersInBoard(controller.board.id))
            .where((t) => t.folderId == folderId)
            .toList()
          ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return children;
  }

  /// Scoped text lookup inside one plan row (the covered board below
  /// reuses no keys, but scoping keeps the assertions exact anyway).
  Finder inPlan(String planId, Finder matching) =>
      find.descendant(of: find.byKey(Key('plan-$planId')), matching: matching);

  // ── P3.1: the navigation shell ───────────────────────────────────────

  testWidgets('main_bar_four_buttons_in_order_calendar_and_library_live', (
    tester,
  ) async {
    await pumpBoard(tester);

    final buttons = find.descendant(
      of: find.byKey(const Key('main-bar')),
      matching: find.byType(IconButton),
    );
    expect(buttons, findsNWidgets(4));
    expect(
      [for (final w in tester.widgetList<IconButton>(buttons)) w.key!],
      const [
        Key('bar-settings'),
        Key('bar-calendar'),
        Key('bar-library'),
        Key('bar-new-event'),
      ],
      reason: 'left→right: Settings · Calendar · Library · New Event',
    );
    // Library is live since P3.1/P3.2 and Calendar since P4.2 (it pushes
    // the Calendar page); Settings and New Event stay present-but-
    // disabled until their chunks.
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('bar-settings')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('bar-calendar')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester.widget<IconButton>(find.byKey(const Key('bar-library'))).onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('bar-new-event')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('bar-home')), findsNothing); // page-local
    expect(find.byKey(const Key('bar-new-list')), findsNothing);

    controller.dispose();
    await store.close();
  });

  testWidgets('library_opens_from_the_bar_and_home_returns_to_the_board', (
    tester,
  ) async {
    await pumpBoard(tester);
    await openLibrary(tester);

    expect(find.text('Library'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('library-bar')),
        matching: find.byType(IconButton),
      ),
      findsNWidgets(3),
    );
    expect(find.byKey(const Key('bar-new-list')), findsOneWidget);
    expect(find.byKey(const Key('bar-delete-list')), findsOneWidget);

    // Home pops the Library — the board root is back.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('library-bar')),
        matching: find.byKey(const Key('bar-home')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('library-page')), findsNothing);
    expect(find.byKey(const Key('main-bar')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // ── P3.2: plan rows ─────────────────────────────────────────────────

  testWidgets('plan_row_meta_count_for_all_open_vs_total_duration', (
    tester,
  ) async {
    await pumpBoard(tester);
    await openLibrary(tester);

    // All-Open plan → item count (singular/plural).
    expect(inPlan(chores.id, find.text('3 items')), findsOneWidget);
    // All-timed plan → total duration.
    expect(inPlan(workout.id, find.text('1m 30s')), findsOneWidget);
    // Mixed plan (120s + Open) → duration, the Open item adds nothing.
    expect(inPlan(weekend.id, find.text('2m')), findsOneWidget);
    // The v1 root plan: a single timed interval → '1m'.
    expect(inPlan(controller.timer.id, find.text('1m')), findsOneWidget);
    // No count on timed rows, no duration on open rows.
    expect(inPlan(workout.id, find.text('2 items')), findsNothing);
    expect(inPlan(chores.id, find.text('3m')), findsNothing);

    controller.dispose();
    await store.close();
  });

  testWidgets('plan_row_shows_created_and_modified_date', (tester) async {
    await pumpBoard(tester);
    await openLibrary(tester);

    expect(
      inPlan(controller.timer.id, find.text('created ${dayOf(t0)}')),
      findsOneWidget,
    );
    expect(
      inPlan(chores.id, find.text('created ${dayOf(t0)}')),
      findsOneWidget,
    );
    // Renamed a day after creation → the modified stamp wins.
    expect(
      inPlan(
        shift.id,
        find.text('modified ${dayOf(t0.add(const Duration(days: 1)))}'),
      ),
      findsOneWidget,
    );
    expect(inPlan(shift.id, find.text('Night shift')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // ── P3.2: the library bar ───────────────────────────────────────────

  testWidgets('new_list_lands_on_top_of_current_folder_and_focuses_rename', (
    tester,
  ) async {
    await pumpBoard(tester);
    await openLibrary(tester);

    // Select Errands as the current folder (tap = current, again = root).
    await tester.tap(find.byKey(Key('folder-name-${errands.id}')));
    await settle(tester);

    await tester.tap(find.byKey(const Key('bar-new-list')));
    await settle(tester);

    final top = (await folderPlans(errands.id)).first;
    expect(top.name, 'New list');
    expect(top.folderId, errands.id);
    final tree = await store.loadTree(top.id);
    expect(tree.roots, isEmpty, reason: 'a fresh list is trivially all-open');
    expect(inPlan(top.id, find.text('0 items')), findsOneWidget);

    // The rename field is focused (typing replaces the selected name) …
    final field = tester.widget<TextField>(
      find.byKey(const Key('plan-rename')),
    );
    expect(field.focusNode!.hasFocus, isTrue);

    // … and the done action commits it.
    await tester.enterText(find.byKey(const Key('plan-rename')), 'Groceries');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect((await folderPlans(errands.id)).first.name, 'Groceries');
    expect(find.byKey(const Key('plan-rename')), findsNothing);

    // Deselect (tap again) → the next list lands on top of the ROOT.
    await tester.tap(find.byKey(Key('folder-name-${errands.id}')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('bar-new-list')));
    await settle(tester);
    final root = await folderPlans(null);
    expect(root.first.name, 'New list');

    controller.dispose();
    await store.close();
  });

  testWidgets('delete_mode_tap_then_confirm_deletes', (tester) async {
    await pumpBoard(tester);
    await openLibrary(tester);

    await tester.tap(find.byKey(const Key('bar-delete-list')));
    await settle(tester);

    // Cancel: nothing happens, the plan stays.
    await tester.tap(find.byKey(Key('plan-${chores.id}')));
    await settle(tester);
    expect(find.text('Delete plan?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Chores'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('dialog-cancel')));
    await settle(tester);
    expect(find.byKey(Key('plan-${chores.id}')), findsOneWidget);

    // Confirm: the plan is gone from the store and from the list.
    await tester.tap(find.byKey(Key('plan-${chores.id}')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('dialog-confirm')));
    await settle(tester);
    expect(find.byKey(Key('plan-${chores.id}')), findsNothing);
    expect((await folderPlans(errands.id)).map((p) => p.name), ['Workout']);
    // Delete mode survives the delete (explicit toggle).
    await tester.tap(find.byKey(const Key('bar-delete-list')));
    await settle(tester);

    controller.dispose();
    await store.close();
  });

  // ── P3.2: folders ───────────────────────────────────────────────────

  testWidgets('folder_create_via_plus_opens_a_focused_inline_rename', (
    tester,
  ) async {
    await pumpBoard(tester);
    await openLibrary(tester);

    await tester.tap(find.byKey(const Key('btn-new-folder')));
    await settle(tester);

    // The existing folders keep rendering while the new one joins them.
    expect(find.byKey(Key('folder-${routines.id}')), findsOneWidget);
    expect(
      (await store.allFolders()).map((f) => f.name),
      contains('New folder'),
    );
    final field = tester.widget<TextField>(
      find.byKey(const Key('folder-rename')),
    );
    expect(field.focusNode!.hasFocus, isTrue);

    await tester.enterText(find.byKey(const Key('folder-rename')), 'Trips');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect((await store.allFolders()).map((f) => f.name), contains('Trips'));
    expect(find.byKey(const Key('folder-rename')), findsNothing);

    controller.dispose();
    await store.close();
  });

  testWidgets('folder_right_click_renames_inline', (tester) async {
    await pumpBoard(tester);
    await openLibrary(tester);

    await tester.tap(
      find.byKey(Key('folder-name-${errands.id}')),
      buttons: kSecondaryMouseButton,
    );
    await settle(tester);
    expect(find.byKey(const Key('folder-rename')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('folder-rename')),
      'Errand Run',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    final renamed = (await store.allFolders()).firstWhere(
      (f) => f.id == errands.id,
    );
    expect(renamed.name, 'Errand Run');
    expect(find.byKey(const Key('folder-rename')), findsNothing);

    controller.dispose();
    await store.close();
  });

  testWidgets('folder_delete_needs_confirmation_and_cascades', (tester) async {
    await pumpBoard(tester);
    await openLibrary(tester);

    await tester.tap(find.byKey(Key('btn-delete-folder-${errands.id}')));
    await settle(tester);
    expect(find.text('Delete folder?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('2 plans'),
      ),
      findsOneWidget,
    );

    // Cancel keeps the folder and its plans.
    await tester.tap(find.byKey(const Key('dialog-cancel')));
    await settle(tester);
    expect(find.byKey(Key('folder-${errands.id}')), findsOneWidget);
    expect((await folderPlans(errands.id)), hasLength(2));

    // Confirm deletes the folder AND its plans; root plans survive.
    await tester.tap(find.byKey(Key('btn-delete-folder-${errands.id}')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('dialog-confirm')));
    await settle(tester);
    expect(find.byKey(Key('folder-${errands.id}')), findsNothing);
    expect((await store.allFolders()).map((f) => f.name), ['Routines']);
    expect(await folderPlans(errands.id), isEmpty);
    final rootNames = (await folderPlans(null)).map((p) => p.name);
    expect(
      rootNames,
      containsAll(<String>['Interval timer', 'Weekend', 'Night shift']),
    );

    controller.dispose();
    await store.close();
  });

  // ── P3.2: drag reorder ──────────────────────────────────────────────

  testWidgets('drag_reorders_plans_within_a_folder', (tester) async {
    await pumpBoard(tester);
    await openLibrary(tester);
    expect((await folderPlans(errands.id)).map((p) => p.name), [
      'Chores',
      'Workout',
    ]);

    // Long-press the first plan and drop it just over Workout's top edge:
    // the dragged proxy's END then sits in Workout's lower half → the
    // drop lands AFTER it (the reorder list's slot rule).
    final choreRect = tester.getRect(find.byKey(Key('plan-${chores.id}')));
    final workoutRect = tester.getRect(find.byKey(Key('plan-${workout.id}')));
    final gesture = await tester.startGesture(choreRect.center);
    await tester.pump(const Duration(milliseconds: 600)); // long-press delay
    await gesture.moveTo(Offset(workoutRect.center.dx, workoutRect.top + 10));
    await tester.pump();
    await gesture.up();
    await settle(tester);

    expect((await folderPlans(errands.id)).map((p) => p.name), [
      'Workout',
      'Chores',
    ], reason: 'the store order follows the drop');
    // The rendered rows follow too.
    expect(
      tester.getTopLeft(find.byKey(Key('plan-${workout.id}'))).dy,
      lessThan(tester.getTopLeft(find.byKey(Key('plan-${chores.id}'))).dy),
    );

    controller.dispose();
    await store.close();
  });

  // ── P3.2: opening a plan ────────────────────────────────────────────

  testWidgets('tapping_a_plan_opens_its_board_and_back_returns', (
    tester,
  ) async {
    await pumpBoard(tester);
    await openLibrary(tester);

    await tester.tap(find.byKey(Key('plan-${workout.id}')));
    await settle(tester);

    // A SECOND controller bound to the plan's timer drives the standard
    // board: its bar and its authored rows are on screen.
    expect(find.byKey(const Key('bar-back')), findsOneWidget);
    expect(find.byKey(const Key('row-w1')), findsOneWidget);
    expect(
      find.text('30'),
      findsOneWidget,
      reason: 'the plan board planned readout of 90s (00 : 01 : 30)',
    );

    // Back → the Library.
    await tester.tap(find.byKey(const Key('bar-back')));
    await settle(tester);
    expect(find.byKey(const Key('bar-back')), findsNothing);
    expect(find.byKey(const Key('library-page')), findsOneWidget);
    expect(find.byKey(Key('plan-${workout.id}')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // P4.3's Home FALLBACK pin: this fixture has NO rules, so nothing
  // claims today (materializeDay would return null) and Home stays the
  // plain pop-to-the-board-root — homeDayDate's null branch.
  testWidgets('plan_board_home_pops_to_the_board_root', (tester) async {
    await pumpBoard(tester);
    await openLibrary(tester);
    await tester.tap(find.byKey(Key('plan-${chores.id}')));
    await settle(tester);
    expect(find.byKey(const Key('plan-bar')), findsOneWidget);

    // Home: the plan board AND the Library go — the board root is back.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('plan-bar')),
        matching: find.byKey(const Key('bar-home')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const Key('plan-bar')), findsNothing);
    expect(find.byKey(const Key('library-page')), findsNothing);
    expect(find.byKey(const Key('main-bar')), findsOneWidget);
    expect(find.byKey(const Key('bar-library')), findsOneWidget);

    controller.dispose();
    await store.close();
  });

  // ── P3.2: save to folder ────────────────────────────────────────────

  testWidgets('right_click_library_saves_to_folder_with_marks_cleared', (
    tester,
  ) async {
    await pumpBoard(tester);
    final before = (await store.timersInBoard(controller.board.id)).length;

    // Right-click = save to folder (it must NOT navigate).
    await tester.tap(
      find.byKey(const Key('bar-library')),
      buttons: kSecondaryMouseButton,
    );
    await settle(tester);
    expect(find.byKey(const Key('library-page')), findsNothing);
    expect(find.text('Save to folder'), findsOneWidget);
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('Errands'), findsOneWidget);
    expect(find.text('Routines'), findsOneWidget);

    // Cancel: no copy.
    await tester.tap(find.byKey(const Key('dialog-cancel')));
    await settle(tester);
    expect((await store.timersInBoard(controller.board.id)).length, before);

    // Pick the folder: the copy lands there, marks cleared (P1.1 fork
    // rule), source untouched.
    await tester.tap(
      find.byKey(const Key('bar-library')),
      buttons: kSecondaryMouseButton,
    );
    await settle(tester);
    await tester.tap(find.byKey(Key('save-folder-${errands.id}')));
    await settle(tester);

    final errandsPlans = await folderPlans(errands.id);
    final copy = errandsPlans.firstWhere((t) => t.name == 'Interval timer');
    expect(copy.folderId, errands.id);

    final copyTree = await store.loadTree(copy.id);
    final copyDefs = [
      for (final n in copyTree.allNodes)
        if (n is DefNode) n.def,
    ];
    expect(copyDefs, hasLength(1));
    expect(copyDefs.single.completed, isFalse, reason: 'marks never travel');
    expect(copyDefs.single.durationSeconds, 60); // structure preserved
    expect(copyDefs.single.id, isNot('a'), reason: 'fresh ids throughout');

    final sourceTree = await store.loadTree(controller.timer.id);
    expect((sourceTree.nodeById('a') as DefNode).def.completed, isTrue);

    controller.dispose();
    await store.close();
  });

  // P4.1: a day's materialized fork lives under its day — the Library
  // lists PLANS only (dayDate != null never appears here).
  testWidgets('day_forks_never_appear_in_the_library', (tester) async {
    final day = DateTime.utc(2026, 3, 2);
    await store.setDayPlan(day, chores.id); // the day claims a plan
    final forkId = await store.materializeDay(day);
    expect(forkId, isNotNull);
    await pumpBoard(tester);
    await openLibrary(tester);
    // The fork exists and is day-owned...
    final all = await store.timersInBoard(controller.board.id);
    expect(all.any((t) => t.id == forkId && t.dayDate != null), isTrue);
    // ...but the Library shows PLANS only.
    expect(
      find.byKey(Key('plan-$forkId')),
      findsNothing,
      reason: 'day forks live under their day, not in the Library',
    );
  });

}

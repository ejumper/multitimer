import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planner_engine/planner_engine.dart';

import 'app_controller.dart';
import 'board_screen.dart';
import 'bottom_bar.dart';
import 'theme.dart';

// P4.3 — day-board navigation shared by every page that opens days or
// lands on Home: the local-day date helpers, the day-board open (the
// calendar's day-row tap, the board's step chevrons), and the Home
// target seam.

/// The local calendar day [time] falls on (CONVENTIONS §7): midnight of
/// the local day — the day-key form [AppController.init]'s `dayDate`
/// speaks.
DateTime dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// Pure CALENDAR day arithmetic at local midnight — a `Duration` add
/// would drift a day across a DST transition (the calendar's rule,
/// P4.2).
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// P4.3's HOME TARGET — the seam P5.2's "Home = specific plan" setting
/// plugs into (it replaces this answer without touching any call site):
/// the day whose board Home opens, or null when nothing claims it —
/// [Store.resolveDayPlan] answers exactly what [Store.materializeDay]
/// would fork, READ-ONLY (Home, like every open, never materializes).
Future<DateTime?> homeDayDate(Store store, DateTime today) async =>
    await store.resolveDayPlan(today) == null ? null : today;

/// Opens [date]'s day board (P4.3): a second [AppController] bound
/// through `init(dayDate:)` driving the standard [BoardScreen] with the
/// plan bar — READ-ONLY at open (the fork happens on the board's first
/// write, P4.1) and disposed when its route pops (its 1 Hz ticker dies
/// with it). The board PUSHES over the current stack, so back walks the
/// days the user swiped through. Callers guard their own double-taps (the
/// async init/push seam).
Future<void> openDayBoard(
  BuildContext context,
  AppController source, {
  required DateTime date,
}) async {
  final dayController = AppController(
    store: source.store,
    clock: source.clock,
    notifier: source.notifier,
    player: source.player,
    soundsDir: source.soundsDir,
    soundListing: source.soundListing,
  );
  await dayController.init(dayDate: date);
  if (!context.mounted) {
    dayController.dispose();
    return;
  }
  await Navigator.of(context).push(
    AppPageRoute<void>(
      builder: (_) => BoardScreen(
        dayController,
        bar: BoardBar.plan,
        ownsController: true, // disposed when the route is gone
      ),
    ),
  );
}

/// P5.1 — SAVE & EDIT TIMER: like [openDayBoard], but the timer editor
/// lands ON the just-captured interval — the day board pushes first
/// (owning the controller through its route), the editor straight on top
/// with [defId] selected and focused ([openPlanEditor]). The
/// returned future resolves when the EDITOR pops; the day board stays
/// underneath (back walks it like any pushed day). Disposed with its
/// route if the caller's context dies during init, exactly like
/// [openDayBoard].
Future<void> openDayBoardEditor(
  BuildContext context,
  AppController source, {
  required DateTime date,
  required String defId,
}) async {
  final dayController = AppController(
    store: source.store,
    clock: source.clock,
    notifier: source.notifier,
    player: source.player,
    soundsDir: source.soundsDir,
    soundListing: source.soundListing,
  );
  await dayController.init(dayDate: date);
  if (!context.mounted) {
    dayController.dispose();
    return;
  }
  final nav = Navigator.of(context);
  final page = nav.context; // the navigator's context outlives the pop
  if (!page.mounted) {
    dayController.dispose();
    return;
  }
  // The board lands FIRST — its route owns the controller — and the editor
  // goes on top at once: its pop reveals the day board, and the board's
  // own pop disposes the controller.
  unawaited(
    nav.push<void>(
      AppPageRoute<void>(
        builder: (_) => BoardScreen(
          dayController,
          bar: BoardBar.plan,
          ownsController: true, // disposed when the route is gone
        ),
      ),
    ),
  );
  await openPlanEditor(page, dayController, focusDefId: defId);
}

/// P4.3 — what every bottom bar's `bar-home` does: land on TODAY'S day
/// board. The stack pops to the board root FIRST (back from Home = the
/// root — wherever it was pressed: Calendar, Library, a plan board, a
/// day board), then today's board pushes on top. A today nothing claims
/// falls back to the plain pop-to-the-board-root — the pre-P4.3
/// behavior — and [homeDayDate] is where P5.2's setting lands.
Future<void> openHome(BuildContext context, AppController controller) async {
  final today = dayOf(controller.clock.now());
  final target = await homeDayDate(controller.store, today);
  if (!context.mounted) return;
  // Capture the navigator BEFORE the pop: the pressed page unmounts with
  // the pop, while the navigator itself outlives it.
  final nav = Navigator.of(context);
  nav.popUntil((r) => r.isFirst);
  if (target == null) return; // nothing claims today → the board root
  final page = nav.context; // the navigator's context outlives the pop
  if (!page.mounted) return;
  await openDayBoard(page, controller, date: target);
}

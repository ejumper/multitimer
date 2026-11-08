/// P5.1 — NEW EVENT quick capture: the dated-interval capture flow behind
/// the main bar's New Event button (v2 outline "New Events").
///
/// The interval editor runs in EVENT MODE over this seam ([EventCapture]
/// is what the button hands it): the date boxes seed [initialDate], and
/// [save] owns the refusal rules AND the write — the editor never touches
/// an [EditorController] in event mode, the interval lands in the TARGET
/// DAY's plan:
///
/// * **insert** (Overwrite OFF, day claimed): [Store.materializeDay]
///   first (the day's OWN copy — the library placeholder is never
///   written), then top-insertion at the roots — first interval, never
///   inside a repeating group (P1.5 exclusivity holds by construction);
/// * **replace** (Overwrite ON) and the **no-plan fallback** (nothing
///   claims the day): a fresh single-interval timer holding the event
///   becomes the day's plan, pinned through [Store.setDayPlan].
///
/// OVERLAP BLOCKING (v2-outline rule): a save whose occupancy window
/// `[trigger, trigger + duration)` hits an existing DATED interval on the
/// day's current plan is REFUSED with a reason and writes nothing — the
/// user picks a non-overlapping time and saves again. A dated Open event
/// occupies its exact trigger; edge-touching windows are not a conflict.
library;

import 'package:planner_engine/planner_engine.dart';

import 'app_controller.dart';
import 'day_navigation.dart';
import 'format.dart';

/// Shown when the `dd mm yy` boxes don't spell a real calendar day — the
/// capture is refused until the boxes do (nothing is written).
const String kEventBadDateReason =
    'Not a real date — check the dd mm yy boxes.';

/// Shown when Save is pressed on a completely empty event (no label, no
/// duration, and Time off) — the same content rule as a plain create.
const String kEventNothingToSaveReason =
    'Nothing to save — add a label, a duration, or a time.';

/// The capture outcome: exactly one side is set. A non-null
/// [blockedReason] = the overlap refusal — NOTHING was written; otherwise
/// [timerId] is the day's plan timer the event landed in and [defId] the
/// new interval (the Save & edit hop opens the editor focused on it).
typedef CaptureResult = ({
  String? blockedReason,
  String? timerId,
  String? defId,
});

/// The date boxes (`dd mm yy`) as the local calendar day they spell, or
/// null when they don't form a REAL date — a non-numeric box, a month
/// outside 1..12, or a day the month doesn't have (31 February rolls
/// into March and is caught by the round-trip check). `yy` is the 2000s
/// (26 → 2026), the 2-digit box width.
DateTime? parseEventDate(String dd, String mm, String yy) {
  final day = int.tryParse(dd);
  final month = int.tryParse(mm);
  final year = int.tryParse(yy);
  if (day == null || month == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1) return null;
  final date = DateTime(2000 + year, month, day);
  if (date.month != month || date.day != day) return null;
  return date;
}

/// The validated date as the live hint under the boxes — `Sun 1 Mar 2026`.
String formatEventDate(DateTime date) =>
    '${_weekdayNames[date.weekday - 1]} ${date.day} '
    '${_monthNames[date.month - 1]} ${date.year}';

const List<String> _weekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The half-open occupancy of a dated def on its day: `[trigger,
/// trigger + duration)`. A dated **Open** event occupies its POINT —
/// widened by the one-second instant `[t, t + 1)` so "conflicts only at
/// the exact trigger" falls out of the same half-open math as everything
/// else (and edge-touching windows never collide). Only dated defs have
/// an occupancy; order-triggered ones sit at no wall time.
({int start, int end}) eventOccupancy(IntervalDef def) {
  final start = def.triggerTimeSeconds!;
  return (start: start, end: start + (def.durationSeconds ?? 1));
}

/// The P5.1 overlap refusal: [candidate]'s occupancy against every
/// EXISTING dated interval of [plan] (roots and plain groups alike).
/// Half-open windows: `[a,b)` vs `[b,c)` never conflicts; a point
/// conflicts where a window contains its instant. Returns the brief
/// on-screen reason, or null when the capture may proceed. An
/// order-triggered candidate has no wall to collide with → null.
String? eventOverlapReason(IntervalTree plan, IntervalDef candidate) {
  if (!candidate.isDated) return null;
  final mine = eventOccupancy(candidate);
  for (final node in plan.allNodes) {
    if (node is! DefNode) continue;
    final other = node.def;
    if (!other.isDated) continue;
    final theirs = eventOccupancy(other);
    if (mine.start >= theirs.end || theirs.start >= mine.end) continue;
    return other.durationSeconds == null
        ? 'That time is taken — an event is set for '
              '${formatWallTime(theirs.start)}. Pick a different time.'
        : 'That time is taken — an event runs '
              '${formatWallTime(theirs.start)}–${formatWallTime(theirs.end)}. '
              'Pick a different time.';
  }
  return null;
}

/// P5.1's capture seam: everything the event-mode interval editor needs to
/// land a dated interval on a TARGET DAY — the seed date, the refusal
/// rules, and the write — over the board that opened it ([source]).
class EventCapture {
  EventCapture({required this.source});

  /// The board that opened the capture: navigation (Save & edit timer
  /// pushes its day board), the fallback board when nothing claims the
  /// day, and the event's seed color ([AppController.timer]'s tint — the
  /// swatches sit right below, the user re-picks any of them).
  final AppController source;

  /// The local day the date boxes seed from (P4.3's day-bind rule: a
  /// date-bound board starts on its own day, the main bar on today).
  DateTime get initialDate => source.dayDate ?? dayOf(source.clock.now());

  /// The P5.1 save: overlap refusal FIRST (read-only — a refused capture
  /// materializes nothing), then the write (see the library doc for the
  /// insert / replace / fallback branches). Returns [CaptureResult] with
  /// the refusal reason or the landed ids.
  Future<CaptureResult> save({
    required String? name,
    required String color,
    required int? durationSeconds,
    required bool autoFinish,
    required String? endAlertSoundFile,
    required int? triggerTimeSeconds,
    required DateTime date,
    required bool overwrite,
  }) async {
    final store = source.store;
    // The draft carries a fresh id; its timerId is a placeholder — every
    // branch re-targets it at the timer actually being written (the
    // engine's saveTree ownership check demands the real owner).
    final draft = IntervalDef(
      id: newUuidV4(),
      timerId: source.timer.id,
      name: name,
      color: color,
      durationSeconds: durationSeconds,
      autoFinish: autoFinish,
      endAlertSoundFile: endAlertSoundFile,
      triggerTimeSeconds: triggerTimeSeconds,
    );

    // 1 — refusal: the day's CURRENT plan (pin else rule winner) may not
    // already hold an interval at this occupancy. Read-only; a blocked
    // save writes nothing — not even a materialization.
    final currentPlanId = await store.resolveDayPlan(date);
    if (currentPlanId != null) {
      final reason = eventOverlapReason(
        await store.loadTree(currentPlanId),
        draft,
      );
      if (reason != null) {
        return (blockedReason: reason, timerId: null, defId: null);
      }
    }

    // 2 — the write. Overwrite never forks the plan it REPLACES (a fresh
    // single-interval timer takes the day's place instead); an insert
    // materializes the day's own copy first, so the placeholder plan is
    // never written.
    if (!overwrite) {
      final materialized = currentPlanId == null
          ? null
          : await store.materializeDay(date);
      if (materialized != null) {
        // Top-insertion at the roots — the first interval of the day's
        // plan, root-level by construction (P1.5 exclusivity).
        final tree = await store.loadTree(materialized);
        await store.saveTree(
          materialized,
          IntervalTree([
            DefNode(_ownedBy(draft, materialized)),
            ...tree.roots,
          ]),
          eventKind: 'event.capture',
          eventPayload: {
            'date': dayNumber(date),
            'defId': draft.id,
            'mode': 'insert',
          },
        );
        return (blockedReason: null, timerId: materialized, defId: draft.id);
      }
    }

    // Replace (Overwrite ON) and the no-plan fallback (the outline's only
    // sane answer when nothing claims the day): one fresh single-
    // interval timer holding the event, pinned as the day's plan.
    final fresh = await store.createTimer(
      boardId: await _boardIdFor(currentPlanId),
      name: draft.name ?? 'Interval timer',
      color: draft.color,
      dayDate: dayNumber(date), // day-owned from birth (P5.1 review fix)
    );
    await store.saveTree(
      fresh.id,
      IntervalTree([DefNode(_ownedBy(draft, fresh.id))]),
      eventKind: 'event.capture',
      eventPayload: {
        'date': dayNumber(date),
        'defId': draft.id,
        'mode': overwrite ? 'replace' : 'fallback',
      },
    );
    await store.setDayPlan(date, fresh.id);
    return (blockedReason: null, timerId: fresh.id, defId: draft.id);
  }

  /// The board a fresh capture timer lands on: the REPLACED plan's own
  /// board when one resolved (mirroring [Store.materializeDay]), else the
  /// board of the controller that opened the capture.
  Future<String> _boardIdFor(String? planId) async {
    if (planId != null) {
      for (final board in await source.store.allBoards()) {
        final match = (await source.store.timersInBoard(
          board.id,
        )).where((t) => t.id == planId);
        if (match.isNotEmpty) return board.id;
      }
    }
    return source.board.id;
  }
}

/// The draft re-owned by the timer actually written — id and every value
/// untouched, only `timerId` changes (P4.1's tree rebase, as a one-field
/// swap for a single def).
IntervalDef _ownedBy(IntervalDef draft, String timerId) =>
    timerId == draft.timerId
    ? draft
    : IntervalDef(
        id: draft.id,
        timerId: timerId,
        name: draft.name,
        color: draft.color,
        durationSeconds: draft.durationSeconds,
        autoFinish: draft.autoFinish,
        endAlertSoundFile: draft.endAlertSoundFile,
        completed: draft.completed,
        triggerTimeSeconds: draft.triggerTimeSeconds,
      );

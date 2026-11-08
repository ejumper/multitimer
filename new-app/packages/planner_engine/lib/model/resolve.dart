/// Default-rule resolution (v2 P3.4): which library plan claims a
/// calendar day? Pure — rules in, winning plan id out; no store, no clock
/// (the caller passes the target day, P4's placeholder reads pass the
/// day's local date).
///
/// Precedence (OVERVIEW §5 / the outline: monthday overrides weekday, a
/// specific date overrides both):
///
/// 1. **date** — a `date` rule for that exact day, AND any weekday/monthday
///    rule with `repeat == false` whose one-off date (its YYYYMMDD value)
///    is that day: a non-repeating "default for this Tuesday" IS a claim
///    on exactly that date, so it counts at DATE precedence and never
///    recurs.
/// 2. **monthday** — a repeating `monthday` rule whose 1–31 value equals
///    the day of month.
/// 3. **weekday** — a repeating `weekday` rule whose 1–7 value (Monday=1)
///    equals the day of week.
/// 4. **default** — a plan's global default rule (matches every day).
///
/// No matching rule → null (the day has no placeholder plan).
///
/// **Tiebreak:** when several plans match at the winning tier, the rule
/// with the SMALLEST id (lexicographic String order) wins. Rule ids are
/// immutable UUID strings assigned at creation, so the winner is fixed for
/// a given rule set and never depends on the caller's list order —
/// deterministic in the sense P3.4 pins ("document the tiebreak").
/// [DriftStore.rulesFor] returns rules in creation order for display;
/// resolution itself is order-independent.
library;

import 'entities.dart';

/// The precedence tier [rule] claims for [date] — 3 = one-off/exact date,
/// 2 = monthday, 1 = weekday, 0 = global default — or null when the rule
/// does not match that day.
int? _tierFor(DefaultRule rule, DateTime date, int day) {
  switch (rule.kind) {
    case DefaultRuleKind.globalDefault:
      return 0;
    case DefaultRuleKind.weekday:
      if (!rule.repeat) {
        // One-off: the value carries the claimed date, not the pattern.
        return rule.value == day ? 3 : null;
      }
      return rule.value == date.weekday ? 1 : null;
    case DefaultRuleKind.monthday:
      if (!rule.repeat) {
        return rule.value == day ? 3 : null;
      }
      return rule.value == date.day ? 2 : null;
    case DefaultRuleKind.date:
      return rule.value == day ? 3 : null;
  }
}

/// Resolves which plan claims [date] from [rules] — pass the rules of ALL
/// plans (P4.1's placeholder reads resolve a day's plan with this).
/// Returns the winning plan's id (the rule's `timerId`), or null when
/// nothing claims the day.
///
/// [date] is read as a CALENDAR day: its year/month/day fields (local
/// time, CONVENTIONS §7) drive the match — the time of day is ignored.
String? resolvePlanFor({
  required List<DefaultRule> rules,
  required DateTime date,
}) {
  final day = date.year * 10000 + date.month * 100 + date.day;

  DefaultRule? best;
  var bestTier = -1;
  for (final rule in rules) {
    final tier = _tierFor(rule, date, day);
    if (tier == null) continue;
    if (tier > bestTier) {
      best = rule;
      bestTier = tier;
      continue;
    }
    // Same tier: the smallest rule id wins (documented tiebreak) — the
    // comparison is stable for any input order.
    if (tier == bestTier && best != null && rule.id.compareTo(best.id) < 0) {
      best = rule;
    }
  }
  return best?.timerId;
}

import 'package:planner_engine/planner_engine.dart';
import 'package:test/test.dart';

/// Default-rule resolution (v2 P3.4): the precedence matrix over all four
/// kinds, conflicts both ways, the documented tiebreak, and the repeat-off
/// one-off-date semantics. Pure — entities in, plan id out; no store.
///
/// Calendar anchors (2026): Mar 1 is a Sunday, so Mar 2 = Monday,
/// Mar 5 = Thursday, Mar 12 = Thursday; Apr 5 = Sunday, May 5 = Tuesday.
void main() {
  /// Shorthand for a rule under [id] claiming for plan [timerId].
  DefaultRule r(
    String id,
    String timerId,
    DefaultRuleKind kind, {
    int? value,
    bool repeat = false,
  }) => DefaultRule(
    id: id,
    timerId: timerId,
    kind: kind,
    value: value,
    repeat: repeat,
  );

  // The four competing plans, one rule each.
  final dateRule = r(
    'r-date',
    'plan-date',
    DefaultRuleKind.date,
    value: 20260305,
  );
  final monthdayRule = r(
    'r-month',
    'plan-monthday',
    DefaultRuleKind.monthday,
    value: 5,
    repeat: true,
  );
  final weekdayRule = r(
    'r-week',
    'plan-weekday',
    DefaultRuleKind.weekday,
    value: 4, // Thursday (Monday=1)
    repeat: true,
  );
  final defaultRule = r(
    'r-default',
    'plan-default',
    DefaultRuleKind.globalDefault,
  );

  final allFour = [dateRule, monthdayRule, weekdayRule, defaultRule];

  String? resolve(List<DefaultRule> rules, DateTime date) =>
      resolvePlanFor(rules: rules, date: date);

  test('precedence: date beats monthday beats weekday beats default', () {
    // 2026-03-05 is a Thursday, the 5th — every rule matches; the DATE
    // rule's plan wins outright.
    expect(resolve(allFour, DateTime(2026, 3, 5)), 'plan-date');
    // 2026-04-05: the 5th but a Sunday — monthday wins over default
    // (no date, no weekday match).
    expect(resolve(allFour, DateTime(2026, 4, 5)), 'plan-monthday');
    // 2026-03-12: a Thursday, the 12th — weekday wins over default.
    expect(resolve(allFour, DateTime(2026, 3, 12)), 'plan-weekday');
    // 2026-03-04: a Wednesday, the 4th — only the global default matches.
    expect(resolve(allFour, DateTime(2026, 3, 4)), 'plan-default');
  });

  test('conflicts both ways: every kind wins when only it matches', () {
    // date vs monthday: the exact day → date; any other 5th → monthday.
    expect(
      resolve([dateRule, monthdayRule], DateTime(2026, 3, 5)),
      'plan-date',
    );
    expect(
      resolve([dateRule, monthdayRule], DateTime(2026, 4, 5)),
      'plan-monthday',
    );
    // monthday vs weekday: overlap day (Thu the 5th) → monthday; a plain
    // Thursday (the 12th) → weekday.
    expect(
      resolve([monthdayRule, weekdayRule], DateTime(2026, 3, 5)),
      'plan-monthday',
    );
    expect(
      resolve([monthdayRule, weekdayRule], DateTime(2026, 3, 12)),
      'plan-weekday',
    );
    // weekday vs default: the weekday's day → weekday; any other day →
    // the default plan.
    expect(
      resolve([weekdayRule, defaultRule], DateTime(2026, 3, 5)),
      'plan-weekday',
    );
    expect(
      resolve([weekdayRule, defaultRule], DateTime(2026, 3, 6)),
      'plan-default',
    );
    // date vs weekday: the exact day → date; another Thursday → weekday.
    expect(resolve([dateRule, weekdayRule], DateTime(2026, 3, 5)), 'plan-date');
    expect(
      resolve([dateRule, weekdayRule], DateTime(2026, 3, 12)),
      'plan-weekday',
    );
  });

  test('resolution is order-independent: reversed rule list, same winner', () {
    final reversed = allFour.reversed.toList();
    expect(resolve(reversed, DateTime(2026, 3, 5)), 'plan-date');
    expect(resolve(reversed, DateTime(2026, 4, 5)), 'plan-monthday');
    expect(resolve(reversed, DateTime(2026, 3, 12)), 'plan-weekday');
    expect(resolve(reversed, DateTime(2026, 3, 4)), 'plan-default');
  });

  test('tiebreak: same tier → the smallest rule id, in any input order', () {
    // Two plans both claiming every day as their global default.
    final a = r('r-aaa', 'plan-a', DefaultRuleKind.globalDefault);
    final b = r('r-zzz', 'plan-b', DefaultRuleKind.globalDefault);
    expect(resolve([b, a], DateTime(2026, 3, 5)), 'plan-a');
    expect(resolve([a, b], DateTime(2026, 3, 5)), 'plan-a');

    // The same tiebreak at the weekday tier (Thursday rules on two plans).
    final w1 = r(
      'r-1',
      'plan-one',
      DefaultRuleKind.weekday,
      value: 4,
      repeat: true,
    );
    final w2 = r(
      'r-2',
      'plan-two',
      DefaultRuleKind.weekday,
      value: 4,
      repeat: true,
    );
    expect(resolve([w2, w1], DateTime(2026, 3, 5)), 'plan-one');
    expect(resolve([w1, w2], DateTime(2026, 3, 5)), 'plan-one');
  });

  test('repeat off: a non-repeating weekday rule is a one-off date', () {
    // "Default for this Tuesday" (repeat off) claims exactly 2026-03-03 —
    // its one-off date counts at DATE precedence.
    final oneOff = r(
      'r-tue',
      'plan-oneoff',
      DefaultRuleKind.weekday,
      value: 20260303,
      repeat: false,
    );
    final everyTuesday = r(
      'r-tuesdays',
      'plan-weekday',
      DefaultRuleKind.weekday,
      value: 2,
      repeat: true,
    );
    // On the claimed date the one-off wins — even over a monthday rule
    // for that day (one-off = date tier, the outline's date > monthday).
    final monthdayOn3rd = r(
      'r-3',
      'plan-monthday',
      DefaultRuleKind.monthday,
      value: 3,
      repeat: true,
    );
    expect(
      resolve([oneOff, everyTuesday], DateTime(2026, 3, 3)),
      'plan-oneoff',
    );
    expect(
      resolve([oneOff, monthdayOn3rd], DateTime(2026, 3, 3)),
      'plan-oneoff',
    );

    // Every OTHER Tuesday: the one-off is spent — the repeating rule wins.
    expect(
      resolve([oneOff, everyTuesday], DateTime(2026, 3, 10)),
      'plan-weekday',
    );
    // And a non-Tuesday: nothing but the one-off's own date matches.
    expect(resolve([oneOff, everyTuesday], DateTime(2026, 3, 4)), isNull);
  });

  test('repeat off: a non-repeating monthday rule is a one-off date', () {
    final oneOff = r(
      'r-may5',
      'plan-oneoff',
      DefaultRuleKind.monthday,
      value: 20260405,
      repeat: false,
    );
    final every5th = r(
      'r-5ths',
      'plan-monthday',
      DefaultRuleKind.monthday,
      value: 5,
      repeat: true,
    );
    // The claimed day → the one-off plan; a later 5th → the repeating one;
    // any day in between → nothing.
    expect(resolve([oneOff, every5th], DateTime(2026, 4, 5)), 'plan-oneoff');
    expect(resolve([oneOff, every5th], DateTime(2026, 5, 5)), 'plan-monthday');
    expect(resolve([oneOff, every5th], DateTime(2026, 4, 6)), isNull);
  });

  test('no matching rule → null (the day has no plan)', () {
    expect(resolve([], DateTime(2026, 3, 5)), isNull);
    // Rules exist but none claims this day: a date rule and a Thursday
    // weekday rule against a Friday with no default rule in sight.
    expect(resolve([dateRule, weekdayRule], DateTime(2026, 3, 6)), isNull);
  });
}

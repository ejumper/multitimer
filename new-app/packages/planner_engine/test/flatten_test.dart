import 'package:planner_engine/planner_engine.dart';
import 'package:test/test.dart';

/// Flatten semantics per `lib/flatten.dart` docs (P1.1). Helpers build
/// trees with short ids (a, b, c… for defs; g1, g2… for groups) purely for
/// readable assertions — real ids are UUIDv4.
void main() {
  const timer = 'T';

  DefNode def(
    String id, {
    String? name,
    String color = '#0055ff',
    int? duration = 60,
    bool autoFinish = true,
    String? endAlertSoundFile,
    bool completed = false,
    int? triggerTime,
  }) => DefNode(
    IntervalDef(
      id: id,
      timerId: timer,
      name: name,
      color: color,
      durationSeconds: duration,
      autoFinish: autoFinish,
      endAlertSoundFile: endAlertSoundFile,
      completed: completed,
      triggerTimeSeconds: triggerTime,
    ),
  );

  GroupNode groupOf(String id, List<IntervalNode> children, {int repeat = 1}) =>
      GroupNode(
        GroupDef(id: id, timerId: timer, repeatCount: repeat),
        children,
      );

  IntervalTree tree(List<IntervalNode> roots) => IntervalTree(roots);

  List<String> defIds(List<IntervalInstance> instances) => [
    for (final i in instances) i.defId,
  ];

  // 3 ungrouped defs emit 3 instances in order
  test('flat_no_groups', () {
    final result = flatten(tree([def('a'), def('b'), def('c')]));
    expect(defIds(result), ['a', 'b', 'c']);
    expect(result.map((i) => i.ordinal), [0, 1, 2]);
  });

  // repeat=2 plays children twice back-to-back
  test('single_group_repeat_2', () {
    final result = flatten(
      tree([
        groupOf('g1', [def('b'), def('c')], repeat: 2),
      ]),
    );
    expect(defIds(result), ['b', 'c', 'b', 'c']);
    expect(result.map((i) => i.ordinal), [0, 1, 2, 3]);
  });

  // inner repeats within each outer pass
  test('nested_groups_inner_repeat', () {
    // outer G3{a, inner G2{b, c}} → a b c b c a b c b c a b c b c
    final result = flatten(
      tree([
        groupOf('g1', [
          def('a'),
          groupOf('g2', [def('b'), def('c')], repeat: 2),
        ], repeat: 3),
      ]),
    );
    expect(defIds(result), [
      'a',
      'b',
      'c',
      'b',
      'c',
      'a',
      'b',
      'c',
      'b',
      'c',
      'a',
      'b',
      'c',
      'b',
      'c',
    ]);
    expect(result, hasLength(15));
  });

  // 6 nested repeat-2 groups → 64 instances
  test('deep_nesting_depth_6', () {
    IntervalNode node = def('a');
    for (var g = 0; g < 6; g++) {
      node = groupOf('g$g', [node], repeat: 2);
    }
    final result = flatten(tree([node]));
    expect(result, hasLength(64));
    expect(defIds(result), everyElement('a'));
    expect(result.map((i) => i.ordinal), Iterable.generate(64));
  });

  // one group over one def → 5 copies
  test('single_interval_group_repeat_5', () {
    final result = flatten(
      tree([
        groupOf('g1', [def('a')], repeat: 5),
      ]),
    );
    expect(result, hasLength(5));
    expect(defIds(result), everyElement('a'));
    expect(result.map((i) => i.ordinal), Iterable.generate(5));
  });

  // repeat=1 plays children exactly once
  test('repeat_1_is_one_pass', () {
    final result = flatten(
      tree([
        groupOf('g1', [def('a'), def('b')], repeat: 1),
      ]),
    );
    expect(defIds(result), ['a', 'b']);
  });

  // empty roots → empty list; totalPlanned is zero
  test('empty_timer', () {
    expect(flatten(tree(const [])), isEmpty);
    expect(totalPlanned(const []), Duration.zero);
  });

  // instances snapshot def values
  test('mixed_colors_and_alerts_snapshot', () {
    var source = IntervalDef(
      id: 'a',
      timerId: timer,
      name: 'Warmup',
      color: '#ff8800',
      durationSeconds: 45,
      autoFinish: false,
      endAlertSoundFile: 'bell.mp3',
    );
    final result = flatten(tree([DefNode(source)]));
    final instance = result.single;
    expect(instance.defId, 'a');
    expect(instance.name, 'Warmup');
    expect(instance.color, '#ff8800');
    expect(instance.durationSeconds, 45);
    expect(instance.autoFinish, false);
    expect(instance.endAlertSoundFile, 'bell.mp3');

    // Re-authoring the def after flattening never mutates the instance.
    source = source.copyWith(
      name: 'Changed',
      color: '#00ff88',
      durationSeconds: 90,
      autoFinish: true,
      endAlertSoundFile: null,
    );
    expect(instance.name, 'Warmup');
    expect(instance.color, '#ff8800');
    expect(instance.durationSeconds, 45);
    expect(instance.autoFinish, false);
    expect(instance.endAlertSoundFile, 'bell.mp3');
  });

  // every ordinal equals its index
  test('instance_ordinals_sequential', () {
    final result = flatten(
      tree([
        def('a'),
        groupOf('g1', [
          def('b'),
          groupOf('g2', [def('c'), def('d')], repeat: 2),
        ], repeat: 3),
        def('e'),
      ]),
    );
    expect(result, isNotEmpty);
    for (var i = 0; i < result.length; i++) {
      expect(result[i].ordinal, i);
    }
  });

  test('total_planned_matches_manual_sum', () {
    final result = flatten(
      tree([
        def('a', duration: 30),
        groupOf('g1', [
          def('b', duration: 45),
          def('c', duration: 15),
        ], repeat: 2),
      ]),
    );
    expect(totalPlanned(result), const Duration(seconds: 150));
  });

  // v2 P1.1: instances snapshot the four-property fields.
  test('instances_snapshot_v2_fields', () {
    final result = flatten(tree([
      def('a', duration: null, autoFinish: false, completed: true),
      def('b', triggerTime: 3600),
    ]));
    expect(result[0].durationSeconds, isNull);
    expect(result[0].isOpen, isTrue);
    expect(result[0].completed, isTrue);
    expect(result[1].triggerTimeSeconds, 3600);
    expect(result[1].isDated, isTrue);
    expect(result[1].completed, isFalse);
  });

  test('totals_sum_known_durations_and_count_open', () {
    final result = flatten(tree([
      def('a', duration: 60),
      def('b', duration: null, autoFinish: false),
      def('c', duration: 90),
    ]));
    expect(totalPlanned(result), const Duration(seconds: 150));
    expect(openCount(result), 1);
    expect(openCount(const []), 0);
    expect(totalPlanned(const []), Duration.zero);
  });


  // v2 P1.4: dated intervals never live in repeating groups (v2 rule) —
  // the engine refuses to flatten them.
  test('dated_in_repeating_group_refuses_to_flatten', () {
    final t = tree([
      groupOf('g', [def('a', triggerTime: 9 * 3600)], repeat: 2),
    ]);
    expect(() => flatten(t), throwsStateError);
    // ...but a dated interval in a NON-repeating group is fine.
    final ok = tree([
      groupOf('g2', [def('b', triggerTime: 9 * 3600)], repeat: 1),
    ]);
    expect(flatten(ok), hasLength(1));
  });

}

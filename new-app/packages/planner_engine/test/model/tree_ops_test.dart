import 'package:planner_engine/planner_engine.dart';
import 'package:test/test.dart';

/// Tree-op semantics per `lib/model/tree.dart` docs (P1.1). Helpers build
/// trees with short ids (a, b, c… for defs; g1, g2… for groups) purely for
/// readable assertions — real ids are UUIDv4.
void main() {
  const timer = 'T';
  var counter = 0;
  String freshId() => 'n${counter++}';

  DefNode def(String id, {int duration = 60, bool autoFinish = true}) =>
      DefNode(
        IntervalDef(
          id: id,
          timerId: timer,
          color: '#0055ff',
          durationSeconds: duration,
          autoFinish: autoFinish,
        ),
      );

  GroupNode groupOf(String id, List<IntervalNode> children, {int repeat = 1}) =>
      GroupNode(
        GroupDef(id: id, timerId: timer, repeatCount: repeat),
        children,
      );

  IntervalTree tree(List<IntervalNode> roots) => IntervalTree(roots);

  group('grouped', () {
    test('wraps consecutive selection at first position', () {
      final t = tree([def('a'), def('b'), def('c')]);
      final r = t.grouped(['a', 'b'], newGroupId: 'g1');
      expect(r.toDebugString(), 'group:g1[1]{def:a | def:b} | def:c');
    });

    test('single-interval group is allowed (CONVENTIONS §1)', () {
      final t = tree([def('a'), def('b')]);
      final r = t.grouped(['b'], newGroupId: 'g1', repeatCount: 3);
      expect(r.toDebugString(), 'def:a | group:g1[3]{def:b}');
    });

    test('non-adjacent selection: in-between items stay outside', () {
      final t = tree([def('a'), def('b'), def('c'), def('d')]);
      final r = t.grouped(['a', 'c'], newGroupId: 'g1');
      expect(r.toDebugString(), 'group:g1[1]{def:a | def:c} | def:b | def:d');
    });

    test('selection order does not matter; relative order preserved', () {
      final t = tree([def('a'), def('b'), def('c')]);
      final r = t.grouped(['c', 'a'], newGroupId: 'g1');
      expect(r.toDebugString(), 'group:g1[1]{def:a | def:c} | def:b');
    });

    test('grouping inside a nested group lands in that group', () {
      final t = tree([
        def('a'),
        groupOf('g1', [def('b'), def('c')], repeat: 2),
      ]);
      final r = t.grouped(['b', 'c'], newGroupId: 'g2');
      expect(
        r.toDebugString(),
        'def:a | group:g1[2]{group:g2[1]{def:b | def:c}}',
      );
    });

    test('rejects: empty selection, non-siblings, repeatCount < 1, dupes', () {
      final t = tree([
        def('a'),
        groupOf('g1', [def('b')]),
      ]);
      expect(
        () => t.grouped([], newGroupId: 'g2'),
        throwsA(isA<TreeOpException>()),
      );
      expect(
        () => t.grouped(['a', 'b'], newGroupId: 'g2'),
        throwsA(isA<TreeOpException>()),
      );
      expect(
        () => t.grouped(['a'], newGroupId: 'g2', repeatCount: 0),
        throwsA(isA<TreeOpException>()),
      );
      expect(
        () => t.grouped(['a', 'a'], newGroupId: 'g2'),
        throwsA(isA<TreeOpException>()),
      );
    });
  });

  group('ungrouped', () {
    test('promotes children into place; nested groups survive', () {
      final t = tree([
        def('a'),
        groupOf('g1', [
          groupOf('g2', [def('b')]),
          def('c'),
        ]),
      ]);
      final r = t.ungrouped('g1');
      expect(r.toDebugString(), 'def:a | group:g2[1]{def:b} | def:c');
    });

    test('ungrouping a nested group keeps the outer group', () {
      final t = tree([
        groupOf('g1', [
          groupOf('g2', [def('b')]),
          def('c'),
        ]),
      ]);
      final r = t.ungrouped('g2');
      expect(r.toDebugString(), 'group:g1[1]{def:b | def:c}');
    });

    test('rejects non-group target and unknown id', () {
      final t = tree([def('a')]);
      expect(() => t.ungrouped('a'), throwsA(isA<TreeOpException>()));
      expect(() => t.ungrouped('zz'), throwsA(isA<TreeOpException>()));
    });
  });

  group('duplicated', () {
    test('copies land below the last selected, original order', () {
      final t = tree([def('a'), def('b'), def('c')]);
      final r = t.duplicated(['a', 'c'], newId: freshId);
      // a and c copied (fresh ids), inserted after c.
      expect(r.roots.length, 5);
      expect(r.toDebugString(), startsWith('def:a | def:b | def:c | def:n'));
      final lastTwo = r.roots.sublist(3).cast<DefNode>();
      // Copies are not the originals.
      expect(lastTwo[0].id, isNot('a'));
      expect(lastTwo[1].id, isNot('c'));
      expect(r.allIds.toSet().length, 5, reason: 'all ids unique');
    });

    test('group subtree is deep-copied with structure + repeat count', () {
      final t = tree([
        def('a'),
        groupOf('g1', [
          def('b'),
          groupOf('g2', [def('c')], repeat: 4),
        ], repeat: 8),
      ]);
      final r = t.duplicated(['g1'], newId: freshId);
      expect(r.roots.length, 3);
      final copy = r.roots[2] as GroupNode;
      expect(copy.group.repeatCount, 8);
      expect(copy.id, isNot('g1'));
      final inner = copy.children[1] as GroupNode;
      expect(inner.group.repeatCount, 4);
      expect(inner.id, isNot('g2'));
      expect(r.allIds.toSet().length, r.allIds.length);
    });

    test('rejects empty / non-sibling selections', () {
      final t = tree([
        def('a'),
        groupOf('g1', [def('b')]),
      ]);
      expect(
        () => t.duplicated([], newId: freshId),
        throwsA(isA<TreeOpException>()),
      );
      expect(
        () => t.duplicated(['a', 'b'], newId: freshId),
        throwsA(isA<TreeOpException>()),
      );
    });
  });

  group('withoutNodes (delete)', () {
    test('removes subtrees; groups emptied by the delete cascade away', () {
      final t = tree([
        groupOf('g1', [def('a')]),
        groupOf('g2', [
          def('b'),
          groupOf('g3', [def('c')]),
        ]),
      ]);
      final r = t.withoutNodes(['a', 'c']);
      // g1 empty → gone; g3 empty → gone; g2 keeps b.
      expect(r.toDebugString(), 'group:g2[1]{def:b}');
    });

    test('deleting a group removes its whole subtree', () {
      final t = tree([
        groupOf('g1', [def('a'), def('b')]),
        def('c'),
      ]);
      final r = t.withoutNodes(['g1']);
      expect(r.toDebugString(), 'def:c');
    });

    test('unknown id throws; empty selection is a no-op', () {
      final t = tree([def('a')]);
      expect(() => t.withoutNodes(['zz']), throwsA(isA<TreeOpException>()));
      expect(t.withoutNodes([]).toDebugString(), t.toDebugString());
    });
  });

  group('moved', () {
    test('reorders within the same parent (index after removal)', () {
      final t = tree([def('a'), def('b'), def('c')]);
      final r = t.moved('a', newParentGroupId: null, newIndex: 2);
      expect(r.toDebugString(), 'def:b | def:c | def:a');
    });

    test('moves into a group at the requested index', () {
      final t = tree([
        def('a'),
        groupOf('g1', [def('b'), def('c')]),
      ]);
      final r = t.moved('a', newParentGroupId: 'g1', newIndex: 1);
      expect(r.toDebugString(), 'group:g1[1]{def:b | def:a | def:c}');
    });

    test('moves a whole group out to root', () {
      final t = tree([
        groupOf('g1', [
          def('a'),
          groupOf('g2', [def('b')]),
        ]),
        def('c'),
      ]);
      final r = t.moved('g2', newParentGroupId: null, newIndex: 0);
      expect(
        r.toDebugString(),
        'group:g2[1]{def:b} | group:g1[1]{def:a} | def:c',
      );
    });

    test('clamps out-of-range index', () {
      final t = tree([def('a'), def('b')]);
      final r = t.moved('a', newParentGroupId: null, newIndex: 99);
      expect(r.toDebugString(), 'def:b | def:a');
    });

    test('moving last child out dissolves the emptied group', () {
      final t = tree([
        def('a'),
        groupOf('g1', [def('b')], repeat: 2),
      ]);
      final r = t.moved('b', newParentGroupId: null, newIndex: 0);
      expect(r.toDebugString(), 'def:b | def:a');
    });

    test('move within a single-child group keeps the group', () {
      final t = tree([
        def('a'),
        groupOf('g1', [def('b')], repeat: 2),
      ]);
      final r = t.moved('b', newParentGroupId: 'g1', newIndex: 0);
      expect(r.toDebugString(), 'def:a | group:g1[2]{def:b}');
    });

    test('rejects moving a group into its own subtree', () {
      final t = tree([
        groupOf('g1', [
          def('a'),
          groupOf('g2', [def('b')]),
        ]),
      ]);
      expect(
        () => t.moved('g1', newParentGroupId: 'g2', newIndex: 0),
        throwsA(isA<TreeOpException>()),
      );
    });
  });

  group('lookups', () {
    test('nodeById / parentOf across nesting', () {
      final t = tree([
        def('a'),
        groupOf('g1', [
          groupOf('g2', [def('b')]),
        ]),
      ]);
      expect(t.nodeById('b'), isA<DefNode>());
      expect(t.parentOf('a'), isNull);
      expect(t.parentOf('g2'), 'g1');
      expect(t.parentOf('b'), 'g2');
      expect(t.allIds, containsAll(['a', 'g1', 'g2', 'b']));
    });
  });
}

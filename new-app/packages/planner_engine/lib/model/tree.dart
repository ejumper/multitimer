/// The interval tree: intervals nest in groups; groups nest uncapped
/// (CONVENTIONS §1). Domain shape — storage encodes it as `GroupDef` rows +
/// `parentGroupId`/`sortIndex` columns (`storage/planner_db.dart`).
///
/// Trees are immutable; every structural op returns a new [IntervalTree] and
/// throws [TreeOpException] on invalid input. Selection semantics (defined
/// here because neither the SPEC nor the outline pins them down — boring
/// MultiTimer-faithful choices, recorded in the P1.1 report):
///
/// - **group**: selected *siblings* (≥1; single-interval groups allowed),
///   non-adjacent allowed. The group lands at the first selected item's
///   position containing the selected nodes in their relative order; items
///   sitting between selections stay outside, shifted after the group.
///   `[a,b,c,d]` group `[a,c]` → `[G(a,c), b, d]`.
/// - **ungroup**: dissolves exactly the targeted group (outermost only);
///   children move up into its place; nested groups survive untouched.
/// - **duplicate**: deep-copies the selected siblings (fresh UUIDs
///   everywhere, structure and repeat counts preserved) in their relative
///   order, inserted directly below the **last** selected node.
///   `[a,b,c]` duplicate `[a,c]` → `[a, b, c, a', c']`.
/// - **delete**: removes the selected subtrees; groups left empty are
///   removed too (cascading upward).
/// - **move**: repositions a subtree under (possibly) another parent;
///   moving a group into its own descendant is rejected.
library;

import 'group_def.dart';
import 'interval_def.dart';

/// Thrown for invalid selections/targets in tree operations.
class TreeOpException implements Exception {
  const TreeOpException(this.message);
  final String message;

  @override
  String toString() => 'TreeOpException: $message';
}

/// A node in the timer's interval tree.
sealed class IntervalNode {
  const IntervalNode();

  /// UUIDv4 of the underlying def (interval or group).
  String get id;

  /// The owning timer (same id on every node of a tree).
  String get timerId;
}

/// Leaf: one authored interval.
class DefNode extends IntervalNode {
  const DefNode(this.def);
  final IntervalDef def;

  @override
  String get id => def.id;

  @override
  String get timerId => def.timerId;
}

/// Bracket: a group with its children, in order.
class GroupNode extends IntervalNode {
  const GroupNode(this.group, this.children);
  final GroupDef group;
  final List<IntervalNode> children;

  @override
  String get id => group.id;

  @override
  String get timerId => group.timerId;
}

/// The full ordered tree of one [IntervalTimer].
class IntervalTree {
  const IntervalTree(this.roots);

  final List<IntervalNode> roots;

  /// Depth-first lookup; throws if absent.
  IntervalNode nodeById(String id) => _locate(roots, id).node;

  /// The parent group's id, or null for root-level nodes.
  String? parentOf(String id) => _locate(roots, id).parentId;

  /// All node ids, depth-first (handy for tests and persistence sanity).
  List<String> get allIds => [
    for (final n in roots) ...[
      n.id,
      if (n is GroupNode) ...IntervalTree(n.children).allIds,
    ],
  ];

  // ── structural ops ──────────────────────────────────────────────────────

  /// Wraps the selected sibling nodes in a new group (see library docs).
  IntervalTree grouped(
    List<String> nodeIds, {
    required String newGroupId,
    int repeatCount = 1,
  }) {
    if (nodeIds.isEmpty) {
      throw const TreeOpException('group needs at least one selected node');
    }
    if (repeatCount < 1) {
      throw const TreeOpException('group repeatCount must be >= 1');
    }
    final locations = _locateAll(roots, nodeIds);
    _ensureSiblings(locations, 'group');
    final timerId = locations.first.node.timerId;

    final ordered = [...locations]..sortBy((l) => l.index);
    final groupNode = GroupNode(
      GroupDef(id: newGroupId, timerId: timerId, repeatCount: repeatCount),
      [for (final l in ordered) l.node],
    );
    final parentId = ordered.first.parentId;
    final insertAt = ordered.first.index;

    return IntervalTree(
      _editChildren(roots, parentId, (siblings) {
        final kept = siblings.where((n) => !nodeIds.contains(n.id)).toList();
        kept.insert(insertAt.clamp(0, kept.length), groupNode);
        return kept;
      }),
    );
  }

  /// Dissolves exactly the targeted group (see library docs).
  IntervalTree ungrouped(String groupId) {
    final loc = _locate(roots, groupId);
    final group = loc.node;
    if (group is! GroupNode) {
      throw const TreeOpException('ungroup: target is not a group');
    }
    return IntervalTree(
      _editChildren(roots, loc.parentId, (siblings) {
        final at = siblings.indexWhere((n) => n.id == groupId);
        return [
          ...siblings.sublist(0, at),
          ...group.children,
          ...siblings.sublist(at + 1),
        ];
      }),
    );
  }

  /// Deep-copies the selected siblings below the last selected node.
  IntervalTree duplicated(
    List<String> nodeIds, {
    required String Function() newId,
  }) {
    if (nodeIds.isEmpty) {
      throw const TreeOpException('duplicate needs at least one selected node');
    }
    final locations = _locateAll(roots, nodeIds);
    _ensureSiblings(locations, 'duplicate');

    final ordered = [...locations]..sortBy((l) => l.index);
    final copies = [for (final l in ordered) _copyNode(l.node, newId)];
    final parentId = ordered.first.parentId;
    final insertAt = ordered.last.index + 1;

    return IntervalTree(
      _editChildren(roots, parentId, (siblings) {
        siblings.insertAll(insertAt.clamp(0, siblings.length), copies);
        return siblings;
      }),
    );
  }

  /// Removes the selected subtrees; emptied groups cascade away.
  IntervalTree withoutNodes(List<String> nodeIds) {
    if (nodeIds.isEmpty) return this;
    _locateAll(roots, nodeIds); // fail loudly on unknown ids
    final ids = nodeIds.toSet();
    List<IntervalNode> prune(List<IntervalNode> nodes) {
      final rebuilt = <IntervalNode>[];
      for (final n in nodes) {
        if (ids.contains(n.id)) continue;
        if (n is GroupNode) {
          final kids = prune(n.children);
          if (kids.isNotEmpty) rebuilt.add(GroupNode(n.group, kids));
        } else {
          rebuilt.add(n);
        }
      }
      return rebuilt;
    }

    return IntervalTree(prune(roots));
  }

  /// Moves a subtree under [newParentGroupId] (null = root) at [newIndex].
  /// The index applies after removal and is clamped into range. Moving the
  /// last child out of a group DISSOLVES that group ("groups are never
  /// empty" invariant — same cascade as [withoutNodes]).
  IntervalTree moved(
    String nodeId, {
    required String? newParentGroupId,
    required int newIndex,
  }) {
    final loc = _locate(roots, nodeId);
    if (newParentGroupId != null) {
      if (newParentGroupId == nodeId) {
        throw const TreeOpException('move: target parent is the node itself');
      }
      // Walk up from the new parent; hitting the moved node = cycle.
      String? cursor = newParentGroupId;
      while (cursor != null) {
        if (cursor == nodeId) {
          throw const TreeOpException(
            'move: cannot move a group into its own subtree',
          );
        }
        cursor = _locateOrNull(roots, cursor)?.parentId;
      }
    }

    final without = _editChildren(
      roots,
      loc.parentId,
      (siblings) => siblings.where((n) => n.id != nodeId).toList(),
    );

    // Guard against the target no longer existing (e.g. removed above).
    if (newParentGroupId != null) _locate(without, newParentGroupId);

    final inserted = _editChildren(without, newParentGroupId, (siblings) {
      siblings.insert(newIndex.clamp(0, siblings.length), loc.node);
      return siblings;
    });
    return IntervalTree(_pruneEmpty(inserted));
  }

  /// Drops any groups left childless (defensive invariant: groups are
  /// never empty). Applied after structural mutations that can empty one.
  static List<IntervalNode> _pruneEmpty(List<IntervalNode> nodes) {
    final rebuilt = <IntervalNode>[];
    for (final n in nodes) {
      if (n is GroupNode) {
        final kids = _pruneEmpty(n.children);
        if (kids.isNotEmpty) rebuilt.add(GroupNode(n.group, kids));
      } else {
        rebuilt.add(n);
      }
    }
    return rebuilt;
  }

  // ── debug/test helpers ──────────────────────────────────────────────────

  /// Compact structural dump, e.g. `def:a | group:g[1]{def:b | def:c}`.
  /// For tests and debugging; not user-facing.
  String toDebugString() => roots.map(_dump).join(' | ');

  String _dump(IntervalNode n) => switch (n) {
    DefNode(:final def) => 'def:${def.id}',
    GroupNode(:final group, :final children) =>
      'group:${group.id}[${group.repeatCount}]{'
          '${children.map(_dump).join(' | ')}}',
  };

  // ── internals ───────────────────────────────────────────────────────────

  static void _ensureSiblings(List<_Location> locations, String op) {
    final first = locations.first.parentId;
    for (final l in locations) {
      if (l.parentId != first) {
        throw TreeOpException('$op: selection must all be siblings');
      }
    }
  }

  /// Locates all [ids]; throws on the first missing one. Positions are the
  /// nodes' indices within their own parent's child list.
  static List<_Location> _locateAll(
    List<IntervalNode> nodes,
    List<String> ids,
  ) {
    final unique = ids.toSet();
    if (unique.length != ids.length) {
      throw const TreeOpException('selection contains duplicates');
    }
    return [
      for (final id in ids)
        () {
          final hit = _locateOrNull(nodes, id);
          if (hit == null) throw TreeOpException('node not found: $id');
          return hit;
        }(),
    ];
  }

  /// Returns a new list where the direct children of [parentId] (null = top
  /// level) are the result of [edit] applied to the current ones.
  static List<IntervalNode> _editChildren(
    List<IntervalNode> nodes,
    String? parentId,
    List<IntervalNode> Function(List<IntervalNode> siblings) edit,
  ) {
    if (parentId == null) return edit([...nodes]);
    return [
      for (final n in nodes)
        if (n is GroupNode && n.id == parentId)
          GroupNode(n.group, edit([...n.children]))
        else if (n is GroupNode)
          GroupNode(n.group, _editChildren(n.children, parentId, edit))
        else
          n,
    ];
  }

  static _Location _locate(List<IntervalNode> nodes, String id) {
    final found = _locateOrNull(nodes, id);
    if (found == null) throw TreeOpException('node not found: $id');
    return found;
  }

  static _Location? _locateOrNull(List<IntervalNode> nodes, String id) {
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      if (n.id == id) return _Location(n, null, i);
      if (n is GroupNode) {
        final hit = _locateOrNull(n.children, id);
        if (hit != null) {
          // Direct child of this group → attribute to it; deeper hits already
          // carry their true parent.
          return hit.parentId == null
              ? _Location(hit.node, n.id, hit.index)
              : hit;
        }
      }
    }
    return null;
  }

  static IntervalNode _copyNode(IntervalNode node, String Function() newId) =>
      switch (node) {
        DefNode(:final def) => DefNode(
          IntervalDef(
            id: newId(),
            timerId: def.timerId,
            name: def.name,
            color: def.color,
            durationSeconds: def.durationSeconds,
            autoFinish: def.autoFinish,
            endAlertSoundFile: def.endAlertSoundFile,
            completionDefault: def.completionDefault,
            trigger: def.trigger,
          ),
        ),
        GroupNode(:final group, :final children) => GroupNode(
          GroupDef(
            id: newId(),
            timerId: group.timerId,
            repeatCount: group.repeatCount,
          ),
          [for (final c in children) _copyNode(c, newId)],
        ),
      };
}

class _Location {
  const _Location(this.node, this.parentId, this.index);
  final IntervalNode node;
  final String? parentId;
  final int index;
}

extension<T> on List<T> {
  void sortBy(int Function(T) keyOf) =>
      sort((a, b) => keyOf(a).compareTo(keyOf(b)));
}

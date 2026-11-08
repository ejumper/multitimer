import 'dart:async';

import 'package:flutter/material.dart';
import 'package:planner_engine/planner_engine.dart';

import 'app_controller.dart';
import 'board_screen.dart';
import 'bottom_bar.dart';
import 'format.dart';
import 'interval_rows.dart';
import 'theme.dart';

/// The Library page (v2 P3.2): the folder-organized home of plans
/// (CONVENTIONS §1 — the folder-organized home of plans that aren't bound
/// to a day; v1's timer arrives as a folder-less plan at the root).
///
/// Content, top to bottom: the board's root plans, the FOLDERS section
/// (its top hosts the bar-less "+" create affordance), then every folder
/// as a section — header (tap = the "current folder" target for new list,
/// right-click = inline rename, × = confirmed delete) followed by its
/// plans. Plan rows speak the editor's interval-row vocabulary
/// ([interval_rows.dart]): title top-left, the item COUNT for all-Open
/// plans or the TOTAL DURATION otherwise top-right, the created/modified
/// ISO date bottom-left; tap opens the plan's board, right-click renames
/// inline, and a long-press drag reorders plans within/between folders
/// (the flat entry list keeps the section landmarks the drop math walks).
///
/// Own bar (P3.1's page-contextual bars): **home** (pop to the board
/// root) · **new list** (all-open plan on TOP of the current folder,
/// focused rename) · **delete list** (delete mode: tap a plan → confirmed
/// delete).
///
/// Save-to-folder (P3.2's quick operation) lives here too and is wired
/// from the board's Library button right-click: [saveTimerToFolder].
class LibraryScreen extends StatefulWidget {
  const LibraryScreen(this.controller, {super.key});

  /// The board's controller — the store seam plus the adapters a plan
  /// board needs when a plan is opened.
  final AppController controller;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  AppController get controller => widget.controller;
  Store get _store => controller.store;

  List<Folder> _folders = const [];
  List<IntervalTimer> _plans = const [];

  /// Each plan's authored tree — the row meta (count vs total duration)
  /// derives from it.
  Map<String, IntervalTree> _trees = const {};

  bool _ready = false;

  /// Delete mode (the bar's delete-list toggle): tapping a plan asks for
  /// confirmation instead of opening its board.
  bool _deleteMode = false;

  /// The folder new lists land in (null = the library root) — set by
  /// creating a folder or tapping a folder header (tap again → root).
  String? _currentFolderId;

  String? _renamingFolderId;
  String? _renamingPlanId;

  /// One open plan board at a time (double-tap guard across the async
  /// init/push seam).
  bool _openingPlan = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final folders = await _store.allFolders();
    // The Library lists PLANS — day forks (P4.1's materialized copies,
    // dayDate != null) live under their day and never appear here.
    final plans = [
      for (final t in await _store.timersInBoard(controller.board.id))
        if (t.dayDate == null) t,
    ];
    final trees = <String, IntervalTree>{};
    for (final plan in plans) {
      trees[plan.id] = await _store.loadTree(plan.id);
    }
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _plans = plans;
      _trees = trees;
      _ready = true;
    });
  }

  /// The folder's plans in display order (ascending sort index; create
  /// lands on top with a smaller one).
  List<IntervalTimer> _plansIn(String? folderId) {
    final children = _plans.where((p) => p.folderId == folderId).toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return children;
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('library-page'),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Same reading width as the board and editor (520).
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: const [
                      Text(
                        'Library',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _ready
                      ? _content()
                      : const SizedBox.shrink(), // one frame of loading
                ),
                const SizedBox(height: 12),
                _bar(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The library bar: home · new list · delete list (P3.1's
  /// page-contextual bar). The delete button tints danger while the
  /// delete mode is armed.
  Widget _bar(BuildContext context) {
    return BottomBar(
      key: const Key('library-bar'),
      buttons: [
        BarButton(
          buttonKey: const Key('bar-home'),
          icon: Icons.home,
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        BarButton(
          buttonKey: const Key('bar-new-list'),
          icon: Icons.playlist_add,
          onPressed: _newList,
        ),
        BarButton(
          buttonKey: const Key('bar-delete-list'),
          icon: Icons.delete_outline,
          color: _deleteMode ? AppColors.danger : AppColors.text,
          onPressed: () => setState(() => _deleteMode = !_deleteMode),
        ),
      ],
    );
  }

  /// The flat entry list: root plans, the folders marker, then each folder
  /// header followed by its plans. This order IS the display order and
  /// the index space [_reorder] walks.
  List<_Entry> _entryList() => [
    for (final plan in _plansIn(null)) _PlanEntry(plan),
    const _FoldersMarkerEntry(),
    for (final folder in _folders) ...[
      _FolderEntry(folder),
      for (final plan in _plansIn(folder.id)) _PlanEntry(plan),
    ],
  ];

  Widget _content() {
    final entries = _entryList();
    return ReorderableListView(
      key: const Key('library-list'),
      // No framework drag handles: plan rows carry their own long-press
      // listeners; folder headers and the marker never drag.
      buildDefaultDragHandles: false,
      onReorderItem: _reorder,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        for (var i = 0; i < entries.length; i++) _buildEntry(entries[i], i),
      ],
    );
  }

  Widget _buildEntry(_Entry entry, int index) => switch (entry) {
    _PlanEntry(:final plan) => _planRow(plan, index),
    _FolderEntry(:final folder) => _folderRow(folder),
    _FoldersMarkerEntry() => _foldersMarker(),
  };

  /// The folders section top (P3.2's bar-less create affordance: the "+").
  Widget _foldersMarker() {
    return Padding(
      key: const Key('folder-new'),
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            'FOLDERS',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 12,
              letterSpacing: 1.5,
              color: AppColors.dimmed,
            ),
          ),
          const Spacer(),
          BarButton(
            buttonKey: const Key('btn-new-folder'),
            icon: Icons.add,
            onPressed: _newFolder,
          ),
        ],
      ),
    );
  }

  Widget _folderRow(Folder folder) {
    final renaming = _renamingFolderId == folder.id;
    final current = _currentFolderId == folder.id;
    return Padding(
      key: Key('folder-${folder.id}'),
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Icon(
            current ? Icons.folder : Icons.folder_outlined,
            size: 18,
            color: current ? AppColors.lightBlue : AppColors.dimmed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: renaming
                ? _InlineRename(
                    fieldKey: const Key('folder-rename'),
                    initial: folder.name,
                    onCommit: (name) => _commitFolderName(folder, name),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Tap = the current folder (again = back to the root);
                    // right-click = inline rename (the outline's long-press
                    // mapping onto this app's right-click vocabulary).
                    onTap: () => setState(
                      () => _currentFolderId = current ? null : folder.id,
                    ),
                    onSecondaryTapDown: (_) =>
                        setState(() => _renamingFolderId = folder.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        folder.name,
                        key: Key('folder-name-${folder.id}'),
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: current ? AppColors.lightBlue : AppColors.text,
                        ),
                      ),
                    ),
                  ),
          ),
          BarButton(
            buttonKey: Key('btn-delete-folder-${folder.id}'),
            icon: Icons.close,
            color: AppColors.dimmed,
            onPressed: () => _confirmDeleteFolder(folder),
          ),
        ],
      ),
    );
  }

  /// One plan row in the editor's row vocabulary (P2.1 tokens): title
  /// top-left; top-right = the ITEM COUNT when every interval is Open
  /// ("3 items", 1 singular) or the TOTAL DURATION otherwise; the
  /// created/modified ISO date bottom-left where the interval cards show
  /// the alert name.
  Widget _planRow(IntervalTimer plan, int index) {
    final tree = _trees[plan.id] ?? const IntervalTree([]);
    final color = hexColor(plan.color);
    final renaming = _renamingPlanId == plan.id;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: renaming
                  ? _InlineRename(
                      fieldKey: const Key('plan-rename'),
                      initial: plan.name,
                      onCommit: (name) => _commitPlanName(plan, name),
                    )
                  : Text(
                      plan.name,
                      style: const TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 15,
                        color: AppColors.text,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              _planMeta(tree),
              key: Key('plan-meta-${plan.id}'),
              style: const TextStyle(
                fontFamily: AppFonts.digits,
                fontSize: 14,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _planStamp(plan),
          key: Key('plan-dates-${plan.id}'),
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 12,
            color: AppColors.dimmed,
          ),
        ),
      ],
    );
    return ReorderableDelayedDragStartListener(
      key: Key('plan-${plan.id}'),
      index: index,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tap: delete mode asks for confirmation, otherwise the plan's
        // board opens. Right-click: inline rename (plans are renameable
        // like folders; the plan's editor can rename too).
        onTap: () {
          if (_deleteMode) {
            unawaited(_confirmDeletePlan(plan));
          } else {
            unawaited(_openPlan(plan));
          }
        },
        onSecondaryTapDown: (_) => setState(() => _renamingPlanId = plan.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          clipBehavior: Clip.antiAlias, // the fill must not square corners
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(
              Radius.circular(AppDecorations.rectRadius),
            ),
            border: Border.all(color: color, width: AppDecorations.borderWidth),
            // The plan's color tinted at the shared card alpha — the
            // interval chips' background rule.
            color: color.withValues(alpha: AppColors.card.a),
          ),
          child: content,
        ),
      ),
    );
  }

  /// The row's top-right meta: the item COUNT for an all-Open plan
  /// (checklist shape — every interval has no duration) or the TOTAL
  /// DURATION otherwise (Open intervals add nothing to the total).
  String _planMeta(IntervalTree tree) {
    final defs = [
      for (final node in tree.allNodes)
        if (node is DefNode) node.def,
    ];
    if (defs.every((d) => d.isOpen)) {
      return '${defs.length} ${defs.length == 1 ? 'item' : 'items'}';
    }
    var total = 0;
    for (final d in defs) {
      total += d.durationSeconds ?? 0;
    }
    return formatDuration(Duration(seconds: total));
  }

  /// The row's bottom-left date: the modified stamp once the plan was
  /// authored past its creation, else the created one — ISO (CONVENTIONS
  /// §7), local-time.
  String _planStamp(IntervalTimer plan) {
    final modified = plan.updatedAt > plan.createdAt;
    final ms = modified ? plan.updatedAt : plan.createdAt;
    final day = DateTime.fromMillisecondsSinceEpoch(ms)
        .toIso8601String()
        .substring(0, 10);
    return '${modified ? 'modified' : 'created'} $day';
  }

  // ── actions ────────────────────────────────────────────────────────────

  Future<void> _newFolder() async {
    final folder = await _store.createFolder('New folder');
    if (!mounted) return;
    await _reload();
    if (!mounted) return;
    // The new folder becomes current and asks for its name.
    setState(() {
      _currentFolderId = folder.id;
      _renamingFolderId = folder.id;
    });
  }

  Future<void> _newList() async {
    // Lands on TOP of the current folder (the store's create rule) as an
    // all-open "list" plan — empty = trivially all-Open — and focuses its
    // rename.
    final plan = await _store.createTimer(
      boardId: controller.board.id,
      name: 'New list',
      color: '#0055ff',
      folderId: _currentFolderId,
    );
    await _reload();
    if (!mounted) return;
    setState(() => _renamingPlanId = plan.id);
  }

  Future<void> _commitFolderName(Folder folder, String name) async {
    setState(() => _renamingFolderId = null);
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == folder.name) return;
    await _store.renameFolder(folder.id, trimmed);
    await _reload();
  }

  Future<void> _commitPlanName(IntervalTimer plan, String name) async {
    setState(() => _renamingPlanId = null);
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == plan.name) return;
    await _store.updateTimer(plan.id, name: trimmed);
    await _reload();
  }

  Future<void> _confirmDeletePlan(IntervalTimer plan) async {
    final confirmed = await _confirm(
      'Delete plan?',
      'The plan "${plan.name}" will be deleted from the Library.',
    );
    if (!confirmed || !mounted) return;
    await _store.deleteTimer(plan.id);
    if (_renamingPlanId == plan.id) {
      _renamingPlanId = null;
    }
    await _reload();
  }

  Future<void> _confirmDeleteFolder(Folder folder) async {
    final count = _plansIn(folder.id).length;
    final plans = count == 1 ? '1 plan' : '$count plans';
    final confirmed = await _confirm(
      'Delete folder?',
      'The folder "${folder.name}" and its $plans will be deleted.',
    );
    if (!confirmed || !mounted) return;
    if (_currentFolderId == folder.id) _currentFolderId = null;
    await _store.deleteFolder(folder.id);
    await _reload();
  }

  Future<bool> _confirm(String title, String message) =>
      showConfirmDialog(context, title: title, message: message);

  /// Opens a plan as its board (P3.2: the outline's "temp board"): a
  /// second [AppController] bound to the plan's timer driving the standard
  /// [BoardScreen] — board root underneath, Library one level below it.
  /// Disposed on pop (its 1 Hz ticker dies with it); the library reloads
  /// afterwards in case the plan was edited there.
  Future<void> _openPlan(IntervalTimer plan) async {
    if (_openingPlan) return;
    _openingPlan = true;
    final planController = AppController(
      store: controller.store,
      clock: controller.clock,
      notifier: controller.notifier,
      player: controller.player,
      soundsDir: controller.soundsDir,
      soundListing: controller.soundListing,
    );
    await planController.init(timerId: plan.id);
    if (!mounted) {
      planController.dispose();
      _openingPlan = false;
      return;
    }
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => BoardScreen(planController, bar: BoardBar.plan),
      ),
    );
    planController.dispose();
    _openingPlan = false;
    if (mounted) await _reload();
  }

  // ── drag-reorder ───────────────────────────────────────────────────────

  /// Reorder callback (ReorderableListView: [newIndex] is the position in
  /// the list with the dragged row already removed). The landed row's
  /// SECTION is the nearest folder header above it (none / the folders
  /// marker crossed on the way = the library root); its position is the
  /// count of same-section plans above it. Same section + same slot =
  /// nothing to do.
  void _reorder(int oldIndex, int newIndex) {
    final entries = _entryList();
    if (oldIndex < 0 || oldIndex >= entries.length) return;
    final entry = entries[oldIndex];
    if (entry is! _PlanEntry) return;

    final removed = List<_Entry>.of(entries)..removeAt(oldIndex);
    final landed = newIndex.clamp(0, removed.length);

    String? targetFolder;
    for (var i = landed - 1; i >= 0; i--) {
      if (removed[i] case _FolderEntry(:final folder)) {
        targetFolder = folder.id;
        break;
      }
    }

    var targetIndex = 0;
    for (var i = landed - 1; i >= 0; i--) {
      final e = removed[i];
      if (targetFolder == null) {
        if (e is _PlanEntry && e.plan.folderId == null) {
          targetIndex++;
          continue;
        }
        if (e is _FoldersMarkerEntry) continue; // above the root block
        break;
      }
      if (e is _PlanEntry && e.plan.folderId == targetFolder) {
        targetIndex++;
        continue;
      }
      break; // the folder header = the section top
    }

    final plan = entry.plan;
    final currentIndex = _plansIn(plan.folderId)
        .indexWhere((p) => p.id == plan.id);
    if (targetFolder == plan.folderId && targetIndex == currentIndex) return;

    unawaited(
      _store
          .moveTimer(
            timerId: plan.id,
            toFolderId: targetFolder,
            toIndex: targetIndex,
          )
          .then((_) => _reload())
          .catchError((Object e) {
            debugPrint('library: reorder failed: $e');
          }),
    );
  }
}

/// The shared confirmation (delete plan / delete folder / make default,
/// P3.4): Cancel (or the barrier) dismisses = false, the confirm button =
/// true — red `Delete` by default; callers may relabel/retint it
/// ([confirmLabel] / [confirmColor]) for non-destructive confirms. Keys
/// follow the board's reset-dialog convention.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  Color confirmColor = AppColors.danger,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.transparent, // effect only behind the menu
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.black, // opaque menu panel
      shape: AppDecorations.menuShape,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          key: const Key('dialog-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('dialog-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel, style: TextStyle(color: confirmColor)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// SAVE TO FOLDER (P3.2 — the Library quick action, right-click on the
/// board's Library button): pick a folder (or the root) and copy the
/// CURRENTLY OPEN timer into it as a new plan. The copy runs through
/// [IntervalTree.copiedToTimer] (P1.1's fork rule): fresh ids throughout,
/// owned by the new timer, completion marks cleared.
Future<void> saveTimerToFolder(
  BuildContext context,
  AppController controller,
) async {
  final store = controller.store;
  final folders = await store.allFolders();
  if (!context.mounted) return;

  final target = await showDialog<_FolderTarget>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.black, // opaque menu panel
      shape: AppDecorations.menuShape,
      title: const Text('Save to folder'),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              key: const Key('save-root'),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(const _FolderTarget(null)),
              child: const Text('Root'),
            ),
            for (final folder in folders)
              TextButton(
                key: Key('save-folder-${folder.id}'),
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_FolderTarget(folder.id)),
                child: Text(folder.name),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('dialog-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(null),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (target == null || !context.mounted) return;

  final source = controller.timer;
  final tree = await store.loadTree(source.id);
  final copy = await store.createTimer(
    boardId: source.boardId,
    name: source.name,
    color: source.color,
    folderId: target.folderId,
  );
  final forked = tree.copiedToTimer(copy.id, newUuidV4);
  await store.saveTree(
    copy.id,
    forked,
    eventKind: 'plan.saveToFolder',
    eventPayload: {'sourceTimerId': source.id, 'folderId': target.folderId},
  );
}

/// The folder-picker dialog's answer: a folder id, or null for the root.
class _FolderTarget {
  const _FolderTarget(this.folderId);
  final String? folderId;
}

/// Inline rename (folders AND plans): the name becomes a focused,
/// select-all text field — committed by the done action (Enter) or by the
/// focus moving away, exactly once.
class _InlineRename extends StatefulWidget {
  const _InlineRename({
    required this.fieldKey,
    required this.initial,
    required this.onCommit,
  });

  final Key fieldKey;
  final String initial;
  final void Function(String) onCommit;

  @override
  State<_InlineRename> createState() => _InlineRenameState();
}

class _InlineRenameState extends State<_InlineRename> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  final FocusNode _focus = FocusNode();
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    // Select the whole name so the first keystroke replaces it (the
    // create flows land here and "ask for the name").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
    });
  }

  void _onFocusChange() {
    if (_focus.hasFocus || _committed) return;
    _commit(); // focus moved away — keep what was typed
  }

  void _commit() {
    if (_committed) return;
    _committed = true;
    widget.onCommit(_text.text);
  }

  @override
  void dispose() {
    // Detach BEFORE disposal: a programmatic unmount (folder deleted
    // under the field) must not fire a late commit.
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: widget.fieldKey,
      focusNode: _focus,
      controller: _text,
      autofocus: true,
      style: const TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: 15,
        color: AppColors.text,
      ),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 2),
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}

/// One row of the library list — the flat entry model the reorder math
/// walks: headers are section landmarks, plans are movable, and the
/// folders marker separates the root block from the folder sections.
sealed class _Entry {
  const _Entry();
}

class _PlanEntry extends _Entry {
  const _PlanEntry(this.plan);
  final IntervalTimer plan;
}

class _FolderEntry extends _Entry {
  const _FolderEntry(this.folder);
  final Folder folder;
}

class _FoldersMarkerEntry extends _Entry {
  const _FoldersMarkerEntry();
}

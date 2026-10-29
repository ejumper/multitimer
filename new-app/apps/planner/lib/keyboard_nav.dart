import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard navigation framework (acceptance "#keyboard navigation").
///
/// Screens declare SECTIONS (the tab-cycle units) and each section owns a
/// grid of [NavCell]s (row/col). One [NavKeyboard] per screen routes key
/// events into a [ScreenNav] controller: Tab/Shift+Tab move between
/// sections, Ctrl+Home/End jump to the first/last section, arrows move
/// within a section's grid (empty cells skipped), Home/End to the first/
/// last cell, Enter activates. While a text field has focus, arrow and
/// Home/End keys belong to the field (typing rule) — the global combos
/// (Tab, Escape, Ctrl+S, Ctrl+Home/End …) still work.

/// The three vertical tracks of the intervals grid (acceptance): arrows
/// up/down move within a track — selectors to selectors, group columns to
/// group columns, rectangles to rectangles ("up from test 3 selects test
/// 4"); left/right walk the row band in reading order.
enum NavKind { selector, bar, content }

/// One keyboard-navigable cell.
class NavCell {
  const NavCell({
    required this.id,
    required this.row,
    required this.col,
    required this.activate,
    this.enabled = true,
    this.kind = NavKind.content,
  });

  /// Vertical track (see [NavKind]).
  final NavKind kind;

  /// Stable id (node id, button key …) — also the focus-ring lookup.
  final String id;

  /// Grid position within the section (rows = visual order; cols = the
  /// selector track (0) then one column per nesting depth).
  final int row;
  final int col;

  /// Enter/activation.
  final VoidCallback activate;

  /// Disabled cells are skipped by every movement (greyed-out buttons).
  final bool enabled;
}

/// One navigable area — the Tab-cycle unit.
class NavSection {
  const NavSection({required this.id, required this.cells});
  final String id;
  final List<NavCell> cells;
}

/// Screen keyboard state: focused section + focused cell.
class ScreenNav extends ChangeNotifier {
  ScreenNav({required this.sections});

  List<NavSection> sections;
  int _sectionIndex = 0;
  String? _focusedId;

  int get sectionIndex => _sectionIndex;
  NavSection get section => sections.isEmpty
      ? const NavSection(id: '', cells: [])
      : sections[_sectionIndex];
  String? get focusedId => _focusedId;

  /// True while [id] is the keyboard-focused cell (drives focus rings).
  bool isFocused(String id) => _focusedId == id;

  List<NavCell> get _cells => section.cells;
  NavCell? get _focused {
    for (final c in _cells) {
      if (c.id == _focusedId) return c;
    }
    return null;
  }

  /// Focus the first enabled cell of the section if nothing is focused yet
  /// (so arrows have an anchor right after Tab).
  void _ensureFocus() {
    if (_focused != null) return;
    for (final c in _cells) {
      if (c.enabled) {
        _focusedId = c.id;
        return;
      }
    }
  }

  /// Rebuild the sections after a screen's state changed (kept focus id
  /// survives; disabled/removed cells fall back to the first enabled).
  void updateSections(List<NavSection> next) {
    sections = next;
    if (_sectionIndex >= sections.length) _sectionIndex = 0;
    if (_focused != null) return; // still resolved lazily per section
    _ensureFocus();
  }

  void focusSection(int index) {
    if (sections.isEmpty) return;
    _sectionIndex = index.clamp(0, sections.length - 1);
    _focusedId = null;
    _ensureFocus();
    notifyListeners();
  }

  /// Tab / Shift+Tab. Returns true when the section changed.
  bool cycleSection(int delta) {
    if (sections.length < 2) return false;
    focusSection((_sectionIndex + delta) % sections.length);
    return true;
  }

  /// Ctrl+Home / Ctrl+End — first/last section.
  void jumpSection(bool toEnd) {
    focusSection(toEnd ? sections.length - 1 : 0);
  }

  /// Arrow movement inside the section grid: horizontal walks the focused
  /// row's cells by column; vertical walks the same COLUMN across rows,
  /// skipping rows that lack that column (the grouped-intervals grid).
  void move(int dRow, int dCol) {
    _ensureFocus();
    final focused = _focused;
    if (focused == null) return;
    if (dCol != 0) {
      // Horizontal: reading order across the whole grid (row-major), so a
      // group's circle steps to its group column and on into its content.
      final all = [..._cells]
        ..sort((a, b) {
          final byRow = a.row.compareTo(b.row);
          return byRow != 0 ? byRow : a.col.compareTo(b.col);
        });
      final at = all.indexWhere((c) => c.id == focused.id);
      var i = at + dCol;
      while (i >= 0 && i < all.length && !all[i].enabled) {
        i += dCol;
      }
      if (i >= 0 && i < all.length) {
        _focusedId = all[i].id;
        notifyListeners();
      }
      return;
    }
    // Vertical: same KIND track (selectors / group columns / rectangles),
    // nearest enabled cell beyond the current row.
    final colCells = [..._cells.where((c) => c.kind == focused.kind)]
      ..sort((a, b) {
        final byRow = a.row.compareTo(b.row);
        return byRow != 0 ? byRow : a.col.compareTo(b.col);
      });
    final at = colCells.indexWhere((c) => c.id == focused.id);
    var i = at + dRow;
    while (i >= 0 && i < colCells.length && !colCells[i].enabled) {
      i += dRow;
    }
    if (i >= 0 && i < colCells.length) {
      _focusedId = colCells[i].id;
      notifyListeners();
    }
  }

  /// Home/End — first/last enabled cell of the section (row-major).
  void jumpCell(bool toEnd) {
    _ensureFocus();
    final cells = [..._cells]..sort((a, b) {
      final byRow = a.row.compareTo(b.row);
      return byRow != 0 ? byRow : a.col.compareTo(b.col);
    });
    final list = toEnd ? cells.reversed.toList() : cells;
    for (final c in list) {
      if (c.enabled) {
        _focusedId = c.id;
        notifyListeners();
        return;
      }
    }
  }

  /// Enter — activate the focused cell (disabled cells never activate).
  void activate() {
    _ensureFocus();
    final focused = _focused;
    if (focused == null || !focused.enabled) return;
    focused.activate();
  }

  /// Ctrl+C / Delete-style actions target the FOCUSED cell's owner.
  NavCell? get focusedCell => _focused;
}

/// True while a text field owns the primary focus — the "typing rule":
/// arrows/Home/End belong to the field; the global combos (Tab, Escape,
/// Ctrl+S, Ctrl+Home/End …) still work. Screens use this to keep their
/// shortcuts from swallowing text-editing keys (Delete, Ctrl+C …).
bool editingFieldHasFocus() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  var typing = false;
  ctx?.visitAncestorElements((element) {
    if (element.widget is EditableText || element.widget is TextField) {
      typing = true;
      return false;
    }
    return true;
  });
  return typing || ctx?.widget is EditableText;
}

/// The visual focus ring for a keyboard-focused cell (the unified 1.4
/// border width, in the text color — same family as the hover circle).
class FocusRing extends StatelessWidget {
  const FocusRing({super.key, required this.focused, required this.child});

  final bool focused;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: focused
            ? Border.all(color: Colors.white, width: 1.4)
            : null,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: child,
    );
  }
}

/// Wraps a screen (or dialog) with the key router. Keys are offered to
/// [onKey] first (screen-specific combos), then to the shared section
/// model. While a text field owns focus, arrow/Home/End keys pass through
/// untouched (typing rule).
class NavKeyboard extends StatefulWidget {
  const NavKeyboard({
    super.key,
    required this.nav,
    required this.child,
    this.onKey,
  });

  final ScreenNav nav;
  final Widget child;

  /// Screen-specific key handling. Return [KeyEventResult.handled] to
  /// swallow, [KeyEventResult.ignored] to fall through to the shared
  /// model, or null to skip the shared model without claiming (used by
  /// modals that swallow everything unlisted).
  final KeyEventResult? Function(KeyEvent event)? onKey;

  @override
  State<NavKeyboard> createState() => _NavKeyboardState();
}

class _NavKeyboardState extends State<NavKeyboard> {
  bool get _typing => editingFieldHasFocus();

  KeyEventResult _handle(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // Screen-specific combos first.
    final custom = widget.onKey?.call(event);
    if (custom != null) return custom;

    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (key == LogicalKeyboardKey.tab) {
      return widget.nav.cycleSection(shift ? -1 : 1)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (ctrl && key == LogicalKeyboardKey.home) {
      widget.nav.jumpSection(false);
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.end) {
      widget.nav.jumpSection(true);
      return KeyEventResult.handled;
    }

    // Typing rule: the remaining keys belong to a focused text field.
    if (_typing) return KeyEventResult.ignored;

    switch (key) {
      case LogicalKeyboardKey.arrowLeft:
        widget.nav.move(0, -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        widget.nav.move(0, 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        widget.nav.move(-1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        widget.nav.move(1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        widget.nav.jumpCell(false);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        widget.nav.jumpCell(true);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        widget.nav.activate();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _handle(event),
      child: widget.child,
    );
  }
}

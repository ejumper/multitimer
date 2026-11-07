import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planner_engine/planner_engine.dart';

import 'adapters/ports.dart';
import 'alert_selector.dart';
import 'duration_utils.dart';
import 'editor_controller.dart';
import 'format.dart';
import 'keyboard_nav.dart';
import 'theme.dart';

/// The per-interval editor (P4.3, UI-REFERENCE item 6 minus the keypad,
/// Start Alert, and Note rows): outlined back circle | "Interval" title,
/// the six color swatches, the label field, then the property toggles —
/// Auto-finish, **Duration**, **Time** (P1.5, in that order) — with the
/// `hr`/`min`/`sec` duration setter (live hint) shown beneath Duration
/// when it is ON, the 24-hour `HH|MM` wall-time setter beneath Time when
/// it is ON, and the End Alert row → [AlertSelectorScreen].
///
/// P1.5 rules carried by the toggles:
///
/// * **Duration OFF** = Open: the duration setter hides and the commit
///   writes `durationSeconds: null`; Auto-finish grays out and is forced
///   off with it (the [IntervalDef] contract: auto-finish requires a
///   duration), and re-enabling Duration leaves it off.
/// * **Time OFF** = order-triggered (`triggerTimeSeconds: null`); ON
///   writes seconds since midnight from the `HH|MM` boxes (no seconds
///   box — decided default). Turning Time ON inside a repeating group is
///   blocked with the exclusivity reason shown on screen.
///
/// LOCAL BUFFERING: every field lives in this widget's state — nothing is
/// pushed to the [controller] until back is tapped ([_commitBack]):
///
/// * CREATE ([defId] == null): a fresh interval is appended iff a label,
///   a duration, or the Time toggle itself was entered (blank label →
///   null name; a name without a duration falls back to the coerced 60s
///   default — [IntervalDef] requires > 0). None → back is a cancel,
///   nothing lands.
/// * EDIT: an existing interval can't be emptied below that same
///   name-or-duration-or-time rule — entering back with neither REVERTS
///   (the def keeps its previous label AND duration, the controller is
///   untouched); otherwise exactly one [EditorController.replaceDef]
///   undo step lands, keeping the previous duration when only the label
///   survives.
///
/// Defaults at open: CREATE seeds the timer's color, Auto-finish OFF,
/// **Duration ON**, **Time OFF** (the hard-coded P1.5 defaults — P5.2
/// settings will feed this seam), an empty label, `00` boxes, and the
/// FIRST file of [soundListing] sorted alphabetically as the end alert
/// (null when the listing is empty — the MultiTimer-faithful default
/// alert); EDIT seeds everything from the def.
class IntervalEditorScreen extends StatefulWidget {
  const IntervalEditorScreen({
    super.key,
    required this.controller,
    this.defId,
    required this.soundsDir,
    required this.soundListing,
    required this.player,
  });

  /// Working-copy controller the back-commit lands in (one undo step).
  final EditorController controller;

  /// Def being edited, looked up once at open; null = CREATE mode.
  final String? defId;

  /// Alert-sounds directory handed to the alert selector.
  final String soundsDir;

  /// Rescan-on-demand file-name listing of [soundsDir].
  final List<String> Function() soundListing;

  /// Preview player handed to the alert selector.
  final SoundPlayer player;

  @override
  State<IntervalEditorScreen> createState() => _IntervalEditorScreenState();
}

class _IntervalEditorScreenState extends State<IntervalEditorScreen> {
  /// The def being edited, read once at open (null in CREATE mode).
  IntervalDef? _def;

  late final TextEditingController _label;
  /// Keyboard model (acceptance): sections back / colors / name /
  /// toggles (auto-finish · duration · time) / duration boxes / time
  /// boxes / end alert — the box sections exist only while their toggle
  /// is ON.
  final ScreenNav _nav = ScreenNav(sections: const []);
  final FocusNode _navFocus = FocusNode();

  /// Real text focus for the name + duration fields (the typing rule).
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _hrFocus = FocusNode();
  final FocusNode _minFocus = FocusNode();
  final FocusNode _secFocus = FocusNode();

  /// The duration boxes in cycle order (Enter / Shift+Enter walk them).
  List<FocusNode> get _boxFocus => [_hrFocus, _minFocus, _secFocus];

  /// The box keyboard adjustments apply to (a focused box wins; otherwise
  /// this one — so the section behaves like a stepped control).
  int _activeBox = 0;

  /// Focus a duration box and select its value (typing replaces).
  void _focusBox(int i) {
    _activeBox = i.clamp(0, 2);
    // The ring is bound directly to the active box — no independent ring
    // movement, so ring and caret can never drift apart.
    _nav.focusCell(['ie-hr', 'ie-min', 'ie-sec'][_activeBox]);
    final node = _boxFocus[_activeBox];
    node.requestFocus();
    final controller = [_hr, _min, _sec][_activeBox];
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  final FocusNode _timeHhFocus = FocusNode();
  final FocusNode _timeMmFocus = FocusNode();

  /// The time boxes in cycle order (same model as [_boxFocus]).
  List<FocusNode> get _timeBoxFocus => [_timeHhFocus, _timeMmFocus];

  /// The active time box (the stepped-control anchor, like [_activeBox]).
  int _activeTimeBox = 0;

  /// Focus a time box and select its value (typing replaces).
  void _focusTimeBox(int i) {
    _activeTimeBox = i.clamp(0, 1);
    _nav.focusCell(['ie-time-hh', 'ie-time-mm'][_activeTimeBox]);
    final node = _timeBoxFocus[_activeTimeBox];
    node.requestFocus();
    final controller = [_timeHh, _timeMm][_activeTimeBox];
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }


  late final TextEditingController _hr;
  late final TextEditingController _min;
  late final TextEditingController _sec;

  /// The wall-time boxes (P1.5): 24-hour `HH|MM`, no seconds box.
  late final TextEditingController _timeHh;
  late final TextEditingController _timeMm;

  /// Local buffers — see the class doc for the commit rules.
  late String _color;
  late bool _autoFinish;

  /// The P1.5 property toggles: Duration (ON = the duration setter shows
  /// and the commit writes a duration; OFF = Open) and Time (ON = the
  /// `HH|MM` setter shows and the commit writes `triggerTimeSeconds`;
  /// OFF = order-triggered). Hard-coded defaults until P5.2 settings.
  late bool _durationOn;
  late bool _timeOn;

  String? _endAlertSoundFile;

  @override
  void initState() {
    super.initState();
    // The "active box" model (acceptance): entering a section hands real
    // text focus there at once — no separate "enter the box" step, so the
    // ring and the caret can never disagree. Select-all on arrival makes
    // typing replace cleanly.
    _nav.onSectionChanged = (id) {
      // The router retakes focus first — a text field may have held it —
      // then hands it on where the section wants it.
      _navFocus.requestFocus();
      if (id == 'name') _nameFocus.requestFocus();
      if (id == 'duration') _focusBox(_activeBox);
      if (id == 'time') _focusTimeBox(_activeTimeBox);
    };
    // Tweaks #1: the editor opens with the name field focused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final i = _nav.sections.indexWhere((s) => s.id == 'name');
      if (i >= 0) _nav.focusSection(i);
    });
    final defId = widget.defId;
    final def = defId == null ? null : _lookupDef(defId);
    _def = def;
    _label = TextEditingController(text: def?.name ?? '');
    if (def == null) {
      // CREATE: `00` boxes, the timer's color, Auto-finish OFF (acceptance
      // "Auto-finish off by default"), **Duration ON / Time OFF** (the
      // hard-coded P1.5 defaults — the P5.2 settings seam feeds these),
      // and the LAST USED sound as the end alert (falling back to the
      // first file alphabetically; empty listing → no alert).
      _hr = TextEditingController(text: '00');
      _min = TextEditingController(text: '00');
      _sec = TextEditingController(text: '00');
      _timeHh = TextEditingController(text: '00');
      _timeMm = TextEditingController(text: '00');
      _color = widget.controller.color;
      _autoFinish = false;
      _durationOn = true;
      _timeOn = false;
      final files = [...widget.soundListing()]..sort();
      _endAlertSoundFile = widget.controller.lastSound ??
          (files.isEmpty ? null : files.first);
    } else {
      // EDIT: seed everything from the def; boxes via the split inverse,
      // the time boxes from the trigger (absent → `00`), and the toggles
      // from the def's shape (Duration from the duration's presence,
      // Time from [IntervalDef.isDated]).
      final parts = splitDuration(Duration(seconds: def.durationSeconds ?? 0));
      _hr = TextEditingController(
        text: parts.hours.toString().padLeft(2, '0'),
      );
      _min = TextEditingController(
        text: parts.minutes.toString().padLeft(2, '0'),
      );
      _sec = TextEditingController(
        text: parts.seconds.toString().padLeft(2, '0'),
      );
      final trigger = def.triggerTimeSeconds;
      _timeHh = TextEditingController(
        text: trigger == null
            ? '00'
            : (trigger ~/ 3600).toString().padLeft(2, '0'),
      );
      _timeMm = TextEditingController(
        text: trigger == null
            ? '00'
            : ((trigger ~/ 60) % 60).toString().padLeft(2, '0'),
      );
      _color = def.color;
      _autoFinish = def.autoFinish;
      _durationOn = def.durationSeconds != null;
      _timeOn = def.isDated;
      _endAlertSoundFile = def.endAlertSoundFile;
    }
  }

  /// EDIT mode only: the def behind [defId]; not a DefNode → loud failure
  /// (the UI only ever opens chips, never groups).
  IntervalDef _lookupDef(String defId) {
    final node = widget.controller.tree.nodeById(defId);
    if (node is! DefNode) {
      throw StateError('IntervalEditorScreen: $defId is not a DefNode');
    }
    return node.def;
  }

  @override
  void dispose() {
    _label.dispose();
    _nameFocus.dispose();
    _navFocus.dispose();
    _hrFocus.dispose();
    _minFocus.dispose();
    _secFocus.dispose();
    _timeHhFocus.dispose();
    _timeMmFocus.dispose();
    _hr.dispose();
    _min.dispose();
    _sec.dispose();
    _timeHh.dispose();
    _timeMm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListenableBuilder(
              listenable: _nav,
              builder: (context, _) {
                _nav.updateSections(_ieSections(context));
                return NavKeyboard(
                  nav: _nav,
                  node: _navFocus,
                  onKey: _onKey,
                  child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 10),
                  _identityCard(),
                  const SizedBox(height: 10),
                  _autoFinishCard(),
                  const SizedBox(height: 10),
                  _durationToggleCard(),
                  if (_durationOn) ...[
                    const SizedBox(height: 10),
                    _durationCard(),
                  ],
                  const SizedBox(height: 10),
                  _timeToggleCard(),
                  if (_timeOn) ...[
                    const SizedBox(height: 10),
                    _timeCard(),
                  ],
                  const SizedBox(height: 10),
                  _alertRow(),
                ],
              ),
                  ),
              );
            },
            ),
          ),
        ),
      ),
    );
  }

  /// Interval-editor keyboard model (acceptance): Escape = back; the
  /// duration boxes use Enter/Shift+Enter to cycle and Up/Down (+Ctrl) to
  /// adjust by 1 / 10 — everything else is the shared section model.
  KeyEventResult? _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;

    // Tweaks #2: while a text field has focus (the name field), Tab /
    // Shift+Tab must move on and Escape must go back — handled here so
    // they cannot get trapped inside the field.
    if (editingFieldHasFocus() && key == LogicalKeyboardKey.tab) {
      _nav.cycleSection(shift ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _commitBack();
      return KeyEventResult.handled;
    }
    // Duration keys work EVEN while a box has focus (acceptance: Up/Down
    // adjust the value, Enter/Shift+Enter cycle the boxes) — they are
    // checked before the typing rule on purpose.
    final inDuration = _nav.section.id == 'duration';

    // The toggle section (P1.5): Space toggles the FOCUSED toggle,
    // Left = off, Right = on — the auto-finish acceptance keys, extended
    // to the Duration and Time toggles (they stack vertically, so Up/Down
    // moves between them). Auto-finish is inert while Duration is OFF.
    if (_nav.section.id == 'toggles' && !editingFieldHasFocus()) {
      final id = _nav.focusedId;
      if (key == LogicalKeyboardKey.space) {
        if (id == 'ie-autofinish') {
          // The engine contract: auto-finish requires a duration — it
          // stays forced off while Duration is OFF (the cell is disabled
          // too, so this is belt and braces).
          if (_durationOn) setState(() => _autoFinish = !_autoFinish);
        } else if (id == 'ie-duration-toggle') {
          _setDurationOn(!_durationOn);
        } else if (id == 'ie-time-toggle') {
          _setTimeOn(!_timeOn);
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        final on = key == LogicalKeyboardKey.arrowRight;
        if (id == 'ie-autofinish') {
          if (_durationOn) setState(() => _autoFinish = on);
        } else if (id == 'ie-duration-toggle') {
          _setDurationOn(on);
        } else if (id == 'ie-time-toggle') {
          _setTimeOn(on);
        }
        return KeyEventResult.handled;
      }
    }

    if (inDuration && (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter)) {
      _cycleBox(shift ? -1 : 1);
      return KeyEventResult.handled;
    }
    // Left/Right belong to the text box (cursor movement) — Enter /
    // Shift+Enter are the ONLY box-cycling keys (acceptance).
    if (inDuration && !alt && (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown)) {
      _adjustBox(key == LogicalKeyboardKey.arrowUp ? 1 : -1, ctrl ? 10 : 1);
      return KeyEventResult.handled;
    }
    // The time setter mirrors the duration keys over its two boxes.
    final inTime = _nav.section.id == 'time';
    if (inTime && (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter)) {
      _cycleTimeBox(shift ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (inTime && !alt && (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown)) {
      _adjustTimeBox(key == LogicalKeyboardKey.arrowUp ? 1 : -1, ctrl ? 10 : 1);
      return KeyEventResult.handled;
    }
    if (editingFieldHasFocus() && !ctrl) return null;
    return null;
  }

  /// Enter/Shift+Enter within the duration section: focus the next/prev
  /// box (wrapping) so typing lands there.
  void _cycleBox(int delta) {
    _focusBox((_activeBox + delta) % _boxFocus.length);
  }

  /// Up/Down within the duration section: adjust the focused box by
  /// [delta] units (Ctrl = 10) with the 2-digit wrap.
  void _adjustBox(int sign, int amount) {
    final boxes = [_hr, _min, _sec];
    final idx = _boxFocus.indexWhere((f) => f.hasFocus);
    if (idx >= 0) _activeBox = idx;
    final i = _activeBox;
    final next = ((int.tryParse(boxes[i].text) ?? 0) + sign * amount)
        .clamp(0, 99);
    boxes[i].text = next.toString().padLeft(2, '0');
    // Keep the selection valid (a stale selection fails the framework's
    // TextEditingValue.isValid check on the next key message).
    boxes[i].selection = TextSelection.collapsed(
      offset: boxes[i].text.length,
    );
  }

  /// The tab-cycle sections (acceptance).
  List<NavSection> _ieSections(BuildContext context) {
    return [
      NavSection(id: 'top', cells: [
        NavCell(
          id: 'ie-back',
          row: 0,
          col: 0,
          activate: _commitBack,
        ),
      ]),
      NavSection(id: 'color', cells: [
        for (var i = 0; i < kPresetSwatches.length; i++)
          NavCell(
            id: 'color-${kPresetSwatches[i]}',
            row: 0,
            col: i,
            activate: () => setState(() => _color = kPresetSwatches[i]),
          ),
      ]),
      NavSection(id: 'name', cells: [
        NavCell(id: 'name', row: 0, col: 0, activate: _nameFocus.requestFocus),
      ]),
      NavSection(id: 'toggles', cells: [
        NavCell(
          id: 'ie-autofinish',
          row: 0,
          col: 0,
          // Grays out with Duration OFF (P1.5): an Open interval always
          // holds manually, so the cell is unreachable while disabled.
          enabled: _durationOn,
          activate: () => setState(() => _autoFinish = !_autoFinish),
        ),
        NavCell(
          id: 'ie-duration-toggle',
          row: 1,
          col: 0,
          activate: () => _setDurationOn(!_durationOn),
        ),
        NavCell(
          id: 'ie-time-toggle',
          row: 2,
          col: 0,
          activate: () => _setTimeOn(!_timeOn),
        ),
      ]),
      if (_durationOn)
        NavSection(id: 'duration', cells: [
          NavCell(
            id: 'ie-hr',
            row: 0,
            col: 0,
            activate: _hrFocus.requestFocus,
          ),
          NavCell(
            id: 'ie-min',
            row: 0,
            col: 1,
            activate: _minFocus.requestFocus,
          ),
          NavCell(
            id: 'ie-sec',
            row: 0,
            col: 2,
            activate: _secFocus.requestFocus,
          ),
        ]),
      if (_timeOn)
        NavSection(id: 'time', cells: [
          NavCell(
            id: 'ie-time-hh',
            row: 0,
            col: 0,
            activate: _timeHhFocus.requestFocus,
          ),
          NavCell(
            id: 'ie-time-mm',
            row: 0,
            col: 1,
            activate: _timeMmFocus.requestFocus,
          ),
        ]),
      NavSection(id: 'endalert', cells: [
        NavCell(id: 'ie-alert-row', row: 0, col: 0, activate: _openAlertSelector),
      ]),
    ];
  }

  /// Outlined back circle (→ [_commitBack]) | centered "Interval" title.
  Widget _header() {
    return Row(
      children: [
        FocusRing(
          focused: _nav.isFocused('ie-back'),
          circular: true,
          child: _BackCircle(key: const Key('ie-back'), onPressed: _commitBack),
        ),
        const Expanded(
          child: Text(
            'Interval',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(width: 48), // balances the back circle for centering
      ],
    );
  }

  /// The six preset swatches (same D11 set as the timer editor); the
  /// selected one shows a ring + center dot. Local [_color], committed on
  /// back.
  /// The color swatches and the name field share ONE background rectangle,
  /// split by a hairline in the border's own style (acceptance).
  Widget _identityCard() {
    return Container(
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final hex in kPresetSwatches) _swatch(hex)],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1.4,
            color: AppColors.cardBorder,
          ),
          FocusRing(
            focused: _nav.isFocused('name'),
            child: _labelField(),
          ),
        ],
      ),
    );
  }

  Widget _swatch(String hex) {
    final selected = _color == hex;
    return FocusRing(
      focused: _nav.isFocused('color-$hex'),
      child: GestureDetector(
      key: Key('ie-swatch-$hex'),
      onTap: () => setState(() => _color = hex),
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hexColor(hex),
          ),
          child: selected
              ? Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: contrastDot(_hexColor(hex)),
                    ),
                  ),
                )
              : null,
        ),
      ),
      ),
    );
  }

  /// Label card — the buffered name lives in [_label]'s text.
  Widget _labelField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        key: const Key('ie-label'),
        focusNode: _nameFocus,
        controller: _label,
        decoration: const InputDecoration(
          hintText: 'Add label',
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// Auto-finish toggle card: the finish-method toggle — off = the
  /// interval holds at zero until manually advanced. Grays out and
  /// forces off while Duration is OFF (auto-finish requires a duration).
  Widget _autoFinishCard() {
    return FocusRing(
      focused: _durationOn && _nav.isFocused('ie-autofinish'),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppDecorations.card,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-finish',
                  key: const Key('ie-autofinish-title'),
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _durationOn ? AppColors.text : AppColors.dimmed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _autoFinish
                      ? 'Next interval starts automatically when this one ends'
                      : 'Holds at zero until you advance',
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12,
                    color: AppColors.dimmed,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('ie-autofinish'),
            value: _autoFinish,
            // Null = disabled: grayed out while Duration is OFF (the
            // engine contract — an Open interval always holds manually).
            onChanged: _durationOn
                ? (value) => setState(() => _autoFinish = value)
                : null,
          ),
        ],
      ),
    ),
  );
  }

  /// Duration toggle card (P1.5): ON shows the duration setter beneath
  /// it; OFF = Open — the setter hides and the commit writes
  /// `durationSeconds: null`. Auto-finish grays out and forces off with
  /// it ([_setDurationOn]).
  Widget _durationToggleCard() {
    return FocusRing(
      focused: _nav.isFocused('ie-duration-toggle'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Duration',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _durationOn
                        ? 'The interval runs for a set length'
                        : 'Open — no duration',
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      color: AppColors.dimmed,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              key: const Key('ie-duration-toggle'),
              value: _durationOn,
              onChanged: _setDurationOn,
            ),
          ],
        ),
      ),
    );
  }

  /// Time toggle card (P1.5): ON shows the `HH|MM` wall-time setter
  /// beneath it and the commit writes `triggerTimeSeconds`; OFF =
  /// order-triggered. Turning it ON inside a repeating group is blocked
  /// by the dated/repeat exclusivity rule ([_setTimeOn]).
  Widget _timeToggleCard() {
    return FocusRing(
      focused: _nav.isFocused('ie-time-toggle'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _timeOn
                        ? 'Starts at this time of day'
                        : 'Starts when the previous interval ends',
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      fontSize: 12,
                      color: AppColors.dimmed,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              key: const Key('ie-time-toggle'),
              value: _timeOn,
              onChanged: _setTimeOn,
            ),
          ],
        ),
      ),
    );
  }


  /// Duration card: three 2-digit boxes (overflow carries UP on every
  /// change) over the live hint — `formatDuration(parsed)`, or `unset`
  /// while the total is zero.
  Widget _durationCard() {
    final parsed = _parsed();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _durationBox(
                key: const Key('ie-hr'),
                navId: 'ie-hr',
                controller: _hr,
                unit: 'hr',
                focusNode: _hrFocus,
              ),
              _durationBox(
                key: const Key('ie-min'),
                navId: 'ie-min',
                controller: _min,
                unit: 'min',
                focusNode: _minFocus,
              ),
              _durationBox(
                key: const Key('ie-sec'),
                navId: 'ie-sec',
                controller: _sec,
                unit: 'sec',
                focusNode: _secFocus,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            parsed == Duration.zero ? 'unset' : formatDuration(parsed),
            key: const Key('ie-duration-hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13,
              color: AppColors.dimmed,
            ),
          ),
        ],
      ),
    );
  }

  /// Time card (P1.5): the wall-time setter in the duration boxes'
  /// interaction model — 24-hour `HH|MM` only (NO seconds box, decided
  /// default) over the live `HH:MM` hint. The boxes carry seconds-since-
  /// midnight into [IntervalDef.triggerTimeSeconds] on commit.
  Widget _timeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _durationBox(
                key: const Key('ie-time-hh'),
                navId: 'ie-time-hh',
                controller: _timeHh,
                unit: 'hh',
                focusNode: _timeHhFocus,
              ),
              _durationBox(
                key: const Key('ie-time-mm'),
                navId: 'ie-time-mm',
                controller: _timeMm,
                unit: 'mm',
                focusNode: _timeMmFocus,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatWallTime(_timeSeconds()),
            key: const Key('ie-time-hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 13,
              color: AppColors.dimmed,
            ),
          ),
        ],
      ),
    );
  }

  /// One box: digits-only, max 2 chars, sanitized on change, centered
  /// digits over a tiny unit caption. [navId] is the keyboard-cell/focus-
  /// ring id (`ie-hr` for the duration boxes, `ie-time-hh` for the time
  /// boxes — the caption stays the short unit).
  Widget _durationBox({
    required Key key,
    required String navId,
    required TextEditingController controller,
    required String unit,
    required FocusNode focusNode,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          child: FocusRing(
            focused: _nav.isFocused(navId),
            child: TextField(
            key: key,
            focusNode: focusNode,
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            style: const TextStyle(
              fontFamily: AppFonts.digits,
              fontSize: 22,
              color: AppColors.text,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 4,
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppDecorations.rectRadius),
                ),
                borderSide: BorderSide(
                  color: AppColors.outline,
                  width: AppDecorations.borderWidth,
                ),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppDecorations.rectRadius),
                ),
                borderSide: BorderSide(
                  color: AppColors.outline,
                  width: AppDecorations.borderWidth,
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(AppDecorations.rectRadius),
                ),
                borderSide: BorderSide(
                  color: AppColors.outline,
                  width: AppDecorations.borderWidth,
                ),
              ),
            ),
            onChanged: (value) => _boxChanged(controller, value),
          ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unit,
          style: const TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11,
            color: AppColors.dimmed,
          ),
        ),
      ],
    );
  }

  /// Sanitize a box edit in place (digits only, ≤ 2) and refresh the hint.
  void _boxChanged(TextEditingController box, String value) {
    final sanitized = sanitizeBox(value);
    if (sanitized != value) {
      box.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
    setState(() {}); // live hint below the boxes
  }

  /// Duration toggle (P1.5): OFF hides the setter and forces Auto-finish
  /// off — the [IntervalDef] contract is auto-finish-requires-a-duration,
  /// so the toggle grays out too. Re-enabling Duration leaves Auto-finish
  /// off (the user re-enables).
  void _setDurationOn(bool on) {
    setState(() {
      _durationOn = on;
      if (!on) _autoFinish = false;
    });
  }

  /// Time toggle (P1.5): ON needs the dated/repeat exclusivity rule — a
  /// dated interval never lives inside a repeating group. Blocked ON
  /// shows the reason on screen and leaves the toggle OFF; OFF always
  /// works (it only moves TOWARD the allowed shape).
  void _setTimeOn(bool on) {
    if (on && !_timeOn) {
      final reason = _repeatConflictReason();
      if (reason != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(reason)));
        return;
      }
    }
    setState(() => _timeOn = on);
  }

  /// The exclusivity reason when turning Time ON would date an interval
  /// inside a repeating group; null = allowed (CREATE lands at the
  /// roots; a def outside any repeating group is fine).
  String? _repeatConflictReason() {
    final defId = widget.defId;
    if (defId == null) return null; // CREATE: appended at the roots
    final parentId = widget.controller.tree.parentOf(defId);
    return widget.controller.insideRepeatingGroup(parentId)
        ? kDatedInRepeatingGroupReason
        : null;
  }

  /// Enter/Shift+Enter within the time section: focus the next/prev box
  /// (wrapping) so typing lands there.
  void _cycleTimeBox(int delta) {
    _focusTimeBox((_activeTimeBox + delta) % _timeBoxFocus.length);
  }

  /// Up/Down within the time section: adjust the focused box by [delta]
  /// units (Ctrl = 10), clamped to the field's 24-hour range — hours
  /// 0..23, minutes 0..59 (wall time never carries upward).
  void _adjustTimeBox(int sign, int amount) {
    final boxes = [_timeHh, _timeMm];
    final idx = _timeBoxFocus.indexWhere((f) => f.hasFocus);
    if (idx >= 0) _activeTimeBox = idx;
    final i = _activeTimeBox;
    final max = i == 0 ? 23 : 59;
    final next = ((int.tryParse(boxes[i].text) ?? 0) + sign * amount)
        .clamp(0, max);
    boxes[i].text = next.toString().padLeft(2, '0');
    // Keep the selection valid (a stale selection fails the framework's
    // TextEditingValue.isValid check on the next key message).
    boxes[i].selection = TextSelection.collapsed(
      offset: boxes[i].text.length,
    );
  }

  /// The time boxes as seconds since midnight (55800 for `15:30`):
  /// hours clamped 0..23, minutes 0..59 — 24-hour wall time has no
  /// carry, so an out-of-range box lands on the nearest edge.
  int _timeSeconds() {
    final hours = _intOf(_timeHh.text).clamp(0, 23);
    final minutes = _intOf(_timeMm.text).clamp(0, 59);
    return hours * 3600 + minutes * 60;
  }

  /// End Alert card: current value (file name minus extension, or
  /// "No alert") + chevron → [AlertSelectorScreen]; the picked value comes
  /// back through the pusher's onSelected into the local buffer.
  Widget _alertRow() {
    final file = _endAlertSoundFile;
    return FocusRing(
      focused: _nav.isFocused('ie-alert-row'),
      child: GestureDetector(
      key: const Key('ie-alert-row'),
      behavior: HitTestBehavior.opaque,
      onTap: _openAlertSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppDecorations.card,
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'End Alert',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            Text(
              file == null ? 'No alert' : _baseName(file),
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                color: AppColors.dimmed,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.dimmed),
          ],
        ),
      ),
    ),
  );
  }


  void _openAlertSelector() {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => AlertSelectorScreen(
          soundsDir: widget.soundsDir,
          soundListing: widget.soundListing,
          player: widget.player,
          selected: _endAlertSoundFile,
          onSelected: (file) => setState(() => _endAlertSoundFile = file),
        ),
      ),
    );
  }

  /// The boxes as ints (empty box = 0), normalized (carry up, no cap).
  ({int hours, int minutes, int seconds}) _boxValues() => (
    hours: _intOf(_hr.text),
    minutes: _intOf(_min.text),
    seconds: _intOf(_sec.text),
  );

  Duration _parsed() {
    final v = _boxValues();
    return normalizeDuration(
      hours: v.hours,
      minutes: v.minutes,
      seconds: v.seconds,
    );
  }

  /// Back-commit — the screen's ONLY write path, as documented on the
  /// class: `hasName` = non-blank label, `hasDur` = Duration ON with a
  /// non-zero box total, `hasTime` = Time ON (the wall trigger itself is
  /// content — a dated interval is an interval). The toggles ride along:
  /// Duration OFF saves `durationSeconds: null` (Open), Time OFF saves
  /// `triggerTimeSeconds: null` (order-triggered).
  ///
  /// * CREATE: append iff `hasName || hasDur || hasTime` (blank label →
  ///   null name; Duration ON with empty boxes → coerced 60s default).
  ///   None → discard.
  /// * EDIT: nothing entered AND no toggle changed → REVERT — keep the
  ///   def's previous contents, do NOT touch the controller. Otherwise
  ///   one [EditorController.replaceDef] step, keeping the previous
  ///   duration when the boxes were emptied but a label remains.
  ///
  /// The route pops either way.
  void _commitBack() {
    final parsed = _parsed();
    final hasName = _label.text.trim().isNotEmpty;
    final hasDur = _durationOn && parsed > Duration.zero;
    final hasTime = _timeOn;
    final defId = widget.defId;
    if (defId == null) {
      if (hasName || hasDur || hasTime) {
        widget.controller.addInterval(
          name: hasName ? _label.text.trim() : null,
          color: _color,
          // IntervalDef requires > 0 — a name-only create with Duration
          // ON gets 60s; Duration OFF is Open (null).
          durationSeconds: _durationOn
              ? (hasDur ? parsed.inSeconds : 60)
              : null,
          autoFinish: _autoFinish,
          endAlertSoundFile: _endAlertSoundFile,
          triggerTimeSeconds: hasTime ? _timeSeconds() : null,
        );
      } // else: a blank create is a cancel — nothing pushed.
    } else {
      final def = _def!;
      // A deliberate toggle flip counts as content: turning Duration or
      // Time off is an edit even with the label and boxes emptied.
      final togglesTouched =
          _durationOn != (def.durationSeconds != null) ||
          _timeOn != def.isDated;
      if (hasName || hasDur || hasTime || togglesTouched) {
        widget.controller.replaceDef(
          defId,
          IntervalDef(
            id: defId,
            timerId: def.timerId,
            name: hasName ? _label.text.trim() : null,
            color: _color,
            durationSeconds: !_durationOn
                ? null
                : (hasDur ? parsed.inSeconds : def.durationSeconds ?? 60),
            autoFinish: _autoFinish,
            endAlertSoundFile: _endAlertSoundFile,
            // An in-place edit never clears the work mark (only reset
            // and copies/forks do).
            completed: def.completed,
            triggerTimeSeconds: _timeOn ? _timeSeconds() : null,
          ),
        );
      } // else: emptied existing interval → revert, touch nothing.
    }
    Navigator.of(context).pop();
  }
}

/// Preset accent swatches (D11), in reference order — the timer editor's
/// set, duplicated as a private copy here.
/// Circular outlined button — the mock board's `_RoundOutlineButton` style,
/// used here for the header's back affordance.
class _BackCircle extends StatelessWidget {
  const _BackCircle({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        shape: const CircleBorder(),
        side: const BorderSide(
          color: AppColors.outline,
          width: AppDecorations.borderWidth,
        ),
        padding: const EdgeInsets.all(12),
      ),
      onPressed: onPressed,
      child: const Icon(Icons.arrow_back, size: 22, color: AppColors.text),
    );
  }
}

/// A box's text as an int (boxes hold digits only; empty = 0).
int _intOf(String raw) => raw.isEmpty ? 0 : int.parse(raw);

/// `chime.mp3` → `chime`: the End Alert value drops the extension.
String _baseName(String file) {
  final dot = file.lastIndexOf('.');
  return dot > 0 ? file.substring(0, dot) : file;
}

/// `#rrggbb` hex (v1 preset swatches) → opaque [Color].
Color _hexColor(String hex) =>
    Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

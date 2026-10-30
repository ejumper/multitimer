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
/// the six color swatches, the label field, the auto-finish toggle, the
/// `hr`/`min`/`sec` duration setter with its live hint, and the End Alert
/// row → [AlertSelectorScreen].
///
/// LOCAL BUFFERING: every field lives in this widget's state — nothing is
/// pushed to the [controller] until back is tapped ([_commitBack]):
///
/// * CREATE ([defId] == null): a fresh interval is appended iff a label OR
///   a duration was entered (blank label → null name; a name without a
///   duration falls back to the coerced 60s default — [IntervalDef]
///   requires > 0). Neither → back is a cancel, nothing lands.
/// * EDIT: an existing interval can't be emptied below that same
///   name-or-duration rule — entering back with neither REVERTS (the def
///   keeps its previous label AND duration, the controller is untouched);
///   otherwise exactly one [EditorController.replaceDef] undo step lands,
///   keeping the previous duration when only the label survives.
///
/// Defaults at open: CREATE seeds the timer's color, auto-finish ON, an
/// empty label, `00` boxes, and the FIRST file of [soundListing] sorted
/// alphabetically as the end alert (null when the listing is empty — the
/// MultiTimer-faithful default alert); EDIT seeds everything from the def.
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
  /// auto-finish / duration / end alert.
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


  late final TextEditingController _hr;
  late final TextEditingController _min;
  late final TextEditingController _sec;

  /// Local buffers — see the class doc for the commit rules.
  late String _color;
  late bool _autoFinish;
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
      // CREATE: `00` boxes, the timer's color, auto-finish OFF (acceptance
      // "Auto-finish off by default"), and the LAST USED sound as the end
      // alert (falling back to the first file alphabetically; empty listing
      // → no alert).
      _hr = TextEditingController(text: '00');
      _min = TextEditingController(text: '00');
      _sec = TextEditingController(text: '00');
      _color = widget.controller.color;
      _autoFinish = false;
      final files = [...widget.soundListing()]..sort();
      _endAlertSoundFile = widget.controller.lastSound ??
          (files.isEmpty ? null : files.first);
    } else {
      // EDIT: seed everything from the def; boxes via the split inverse.
      final parts = splitDuration(Duration(seconds: def.durationSeconds));
      _hr = TextEditingController(
        text: parts.hours.toString().padLeft(2, '0'),
      );
      _min = TextEditingController(
        text: parts.minutes.toString().padLeft(2, '0'),
      );
      _sec = TextEditingController(
        text: parts.seconds.toString().padLeft(2, '0'),
      );
      _color = def.color;
      _autoFinish = def.autoFinish;
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
    _hr.dispose();
    _min.dispose();
    _sec.dispose();
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
                  _durationCard(),
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

    // Auto-finish section: Space toggles, Left = off, Right = on.
    if (_nav.section.id == 'autofinish') {
      if (key == LogicalKeyboardKey.space) {
        setState(() => _autoFinish = !_autoFinish);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft && !_autoFinish) {
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
        setState(() => _autoFinish = key == LogicalKeyboardKey.arrowRight);
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
    if (inDuration && (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown)) {
      _adjustBox(key == LogicalKeyboardKey.arrowUp ? 1 : -1, ctrl ? 10 : 1);
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
      NavSection(id: 'autofinish', cells: [
        NavCell(
          id: 'ie-autofinish',
          row: 0,
          col: 0,
          activate: () => setState(() => _autoFinish = !_autoFinish),
        ),
      ]),
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

  /// Auto-finish toggle card: the ONLY property toggle — off = the
  /// interval holds at zero until manually advanced.
  Widget _autoFinishCard() {
    return FocusRing(
      focused: _nav.isFocused('ie-autofinish'),
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
                  'Auto-finish',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
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
            onChanged: (value) => setState(() => _autoFinish = value),
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
                controller: _hr,
                unit: 'hr',
                focusNode: _hrFocus,
              ),
              _durationBox(
                key: const Key('ie-min'),
                controller: _min,
                unit: 'min',
                focusNode: _minFocus,
              ),
              _durationBox(
                key: const Key('ie-sec'),
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

  /// One box: digits-only, max 2 chars, sanitized on change, centered
  /// digits over a tiny unit caption.
  Widget _durationBox({
    required Key key,
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
            focused: _nav.isFocused('ie-$unit'),
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
  /// class: `hasName` = non-blank label, `hasDur` = non-zero duration.
  ///
  /// * CREATE: append iff `hasName || hasDur` (blank label → null name;
  ///   no duration → coerced 60s default). Neither → discard.
  /// * EDIT: `!hasName && !hasDur` → REVERT — keep the def's previous
  ///   label AND duration, do NOT touch the controller. Otherwise one
  ///   [EditorController.replaceDef] step, keeping the previous duration
  ///   when the boxes were emptied but a label remains.
  ///
  /// The route pops either way.
  void _commitBack() {
    final parsed = _parsed();
    final hasName = _label.text.trim().isNotEmpty;
    final hasDur = parsed > Duration.zero;
    final defId = widget.defId;
    if (defId == null) {
      if (hasName || hasDur) {
        widget.controller.addInterval(
          name: hasName ? _label.text.trim() : null,
          color: _color,
          // IntervalDef requires > 0 — a name-only create gets 60s.
          durationSeconds: hasDur ? parsed.inSeconds : 60,
          autoFinish: _autoFinish,
          endAlertSoundFile: _endAlertSoundFile,
        );
      } // else: a blank create is a cancel — nothing pushed.
    } else if (hasName || hasDur) {
      final def = _def!;
      widget.controller.replaceDef(
        defId,
        IntervalDef(
          id: defId,
          timerId: def.timerId,
          name: hasName ? _label.text.trim() : null,
          color: _color,
          durationSeconds: hasDur ? parsed.inSeconds : def.durationSeconds,
          autoFinish: _autoFinish,
          endAlertSoundFile: _endAlertSoundFile,
        ),
      );
    } // else: emptied existing interval → revert, touch nothing.
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

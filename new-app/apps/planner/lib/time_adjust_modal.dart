import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'keyboard_nav.dart';
import 'theme.dart';

/// Tweaks #7 — the ephemeral "+/- time" menu (left of Choose interval):
/// a duration setter with a SIGN box prepended — `[±] [hh] [mm] [ss]` —
/// adjusting the CURRENT instance's remaining for this run only (never
/// the saved definition).
///
/// Keyboard (the duration setter's active-box model):
///  - Enter / Shift+Enter cycle the boxes (wrap);
///  - ↑ / ↓ toggle the sign box; on hh/mm/ss they adjust by 1 (Ctrl: 10);
///  - ← / → are text-cursor keys inside the focused box;
///  - Esc / Ctrl+S apply + close, Shift+Esc cancels (the editor's
///    Done/discard convention).
///
/// Returns the signed delta in seconds, or null when cancelled.
Future<int?> showTimeAdjustModal(BuildContext context) =>
    showDialog<int>(
      context: context,
      barrierColor: Colors.transparent, // effect only behind the menu
      builder: (context) => const _TimeAdjustModal(),
    );

class _TimeAdjustModal extends StatefulWidget {
  const _TimeAdjustModal();

  @override
  State<_TimeAdjustModal> createState() => _TimeAdjustModalState();
}

class _TimeAdjustModalState extends State<_TimeAdjustModal> {
  /// Box order: sign, hours, minutes, seconds — the active-box model.
  final List<FocusNode> _boxFocus = [for (var i = 0; i < 4; i++) FocusNode()];
  final FocusNode _navFocus = FocusNode();
  late final TextEditingController _sign;
  late final TextEditingController _hr;
  late final TextEditingController _min;
  late final TextEditingController _sec;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _sign = TextEditingController(text: '+');
    _hr = TextEditingController(text: '00');
    _min = TextEditingController(text: '00');
    _sec = TextEditingController(text: '00');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusBox(0);
    });
  }

  @override
  void dispose() {
    for (final f in _boxFocus) {
      f.dispose();
    }
    _navFocus.dispose();
    _sign.dispose();
    _hr.dispose();
    _min.dispose();
    _sec.dispose();
    super.dispose();
  }

  TextEditingController get _box0 => _sign;
  List<TextEditingController> get _durationBoxes => [_hr, _min, _sec];

  /// The signed delta in seconds.
  int get _deltaSeconds {
    final h = int.tryParse(_hr.text) ?? 0;
    final m = int.tryParse(_min.text) ?? 0;
    final s = int.tryParse(_sec.text) ?? 0;
    final magnitude = h * 3600 + m * 60 + s;
    return _sign.text == '-' ? -magnitude : magnitude;
  }

  /// Focused box + ring move together (the active-box model).
  void _focusBox(int i) {
    setState(() => _active = i);
    final node = _boxFocus[i];
    node.requestFocus();
    final controller = i == 0 ? _box0 : _durationBoxes[i - 1];
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  void _cycleBox(int delta) => _focusBox((_active + delta) % 4);

  /// Up/Down on a duration box: ±[amount] with the 2-digit wrap.
  void _adjustBox(int sign, int amount) {
    final controller = _durationBoxes[_active - 1];
    final next = ((int.tryParse(controller.text) ?? 0) + sign * amount)
        .clamp(0, 99);
    controller.text = next.toString().padLeft(2, '0');
    // Keep the selection valid (a stale selection fails the framework's
    // TextEditingValue.isValid check on the next key message).
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    setState(() {}); // the hint line
  }

  void _toggleSign() {
    setState(() => _sign.text = _sign.text == '-' ? '+' : '-');
    _sign.selection = TextSelection.collapsed(offset: _sign.text.length);
  }

  KeyEventResult? _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(shift ? 0 : _deltaSeconds);
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyS) {
      Navigator.of(context).pop(_deltaSeconds);
      return KeyEventResult.handled;
    }
    // Tab cycles the boxes as well — keyboard users reach everything via
    // Esc / Shift+Esc / Ctrl+S, and the ring must never drift from the
    // caret onto a button.
    if (key == LogicalKeyboardKey.tab) {
      _cycleBox(shift ? -1 : 1);
      return KeyEventResult.handled;
    }
    // Enter / Shift+Enter cycle the boxes (the duration-setter model) —
    // Left/Right belong to the text cursor.
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _cycleBox(shift ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (_active == 0) {
        _toggleSign(); // either arrow toggles (TWEAKS.md #7)
      } else {
        _adjustBox(key == LogicalKeyboardKey.arrowUp ? 1 : -1, ctrl ? 10 : 1);
      }
      return KeyEventResult.handled;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _navFocus,
      onKeyEvent: (node, event) => _onKey(event) ?? KeyEventResult.ignored,
      child: Dialog(
        key: const Key('adjust-modal'),
        backgroundColor: Colors.black, // opaque menu panel
        constraints: const BoxConstraints(minWidth: 340),
        shape: AppDecorations.menuShape,
        child: SizedBox(
          width: 340,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _signBox(),
                    const SizedBox(width: 6),
                    _durationBox(1, controller: _hr, unit: 'hr'),
                    const _colon(),
                    _durationBox(2, controller: _min, unit: 'min'),
                    const _colon(),
                    _durationBox(3, controller: _sec, unit: 'sec'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _deltaSeconds == 0
                      ? 'unset'
                      : '${_deltaSeconds > 0 ? '+' : '-'}'
                            '${formatDuration(Duration(seconds: _deltaSeconds.abs()))}',
                  key: const Key('adjust-hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 13,
                    color: AppColors.dimmed,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1.4),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      key: const Key('adjust-cancel'),
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(0),
                    ),
                    TextButton(
                      key: const Key('adjust-apply'),
                      onPressed: () => Navigator.of(context).pop(_deltaSeconds),
                      child: const Text(
                        'APPLY',
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The sign box: one char, `+`/`-` (typed or toggled with ↑/↓).
  Widget _signBox() {
    return SizedBox(
      width: 44,
      child: FocusRing(
        focused: _active == 0,
        child: TextField(
          key: const Key('adjust-sign'),
          focusNode: _boxFocus[0],
          controller: _sign,
          textAlign: TextAlign.center,
          onTap: () => _focusBox(0),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[+-]')),
            LengthLimitingTextInputFormatter(1),
          ],
          style: const TextStyle(
            fontFamily: AppFonts.digits,
            fontSize: 22,
            color: AppColors.text,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
    );
  }

  /// One duration box — the interval editor's duration-setter style.
  Widget _durationBox(
    int index, {
    required TextEditingController controller,
    required String unit,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 58,
          child: FocusRing(
            focused: _active == index,
            child: TextField(
              key: Key('adjust-$unit'),
              focusNode: _boxFocus[index],
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              onTap: () => _focusBox(index),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              style: const TextStyle(
                fontFamily: AppFonts.digits,
                fontSize: 22,
                color: AppColors.text,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
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
}

class _colon extends StatelessWidget {
  const _colon();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 2),
    child: Text(
      ':',
      style: TextStyle(
        fontFamily: AppFonts.digits,
        fontSize: 22,
        color: AppColors.dimmed,
      ),
    ),
  );
}

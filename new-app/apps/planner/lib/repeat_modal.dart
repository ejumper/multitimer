import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keyboard_nav.dart';

import 'theme.dart';

/// The repeat stepper popover (UI-REFERENCE item 8): `− N +` over a
/// divider and a full-width OK — N = total passes, floored at 1 (1 = play
/// once). Returns the confirmed count, or null when dismissed without OK
/// (barrier tap / back) — the caller then leaves the group untouched.
Future<int?> showRepeatModal(BuildContext context, {required int initial}) {
  return showDialog<int>(
    context: context,
    barrierColor: Colors.transparent, // effect only behind the menu
    builder: (context) => _RepeatModal(initial: initial),
  );
}

/// The dialog body — a small stateful widget owning the live count, so the
/// stepper survives its own setState rebuilds.
class _RepeatModal extends StatefulWidget {
  const _RepeatModal({required this.initial});

  final int initial;

  @override
  State<_RepeatModal> createState() => _RepeatModalState();
}

class _RepeatModalState extends State<_RepeatModal> {
  /// Keyboard (acceptance): Left/Right = -/+1, Ctrl+Left/Right = -/+10,
  /// Enter = OK, Escape = cancel (DismissIntent pops).
  late final ScreenNav _nav = ScreenNav(
    sections: [
      NavSection(id: 'stepper', cells: [
        NavCell(
          id: 'repeat-ok',
          row: 0,
          col: 0,
          activate: () => Navigator.of(context).pop(_count),
        ),
      ]),
    ],
  )..focusSection(0);

  KeyEventResult? _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final step = (ctrl ? 10 : 1) * (key == LogicalKeyboardKey.arrowRight ? 1 : -1);
      setState(() => _count = (_count + step).clamp(1, 9999));
      return KeyEventResult.handled;
    }
    return null; // Enter -> shared model (OK); Escape -> DismissIntent
  }

  /// Live pass count; never drops below 1.
  late int _count = widget.initial < 1 ? 1 : widget.initial;

  @override
  Widget build(BuildContext context) {
    return NavKeyboard(
      nav: _nav,
      onKey: _onKey,
      child: ListenableBuilder(
        listenable: _nav,
        builder: (_, _) => Dialog(
      key: const Key('repeat-modal'),
      backgroundColor: Colors.black, // opaque menu panel
      constraints: const BoxConstraints(minWidth: 220),
      shape: AppDecorations.menuShape,
      child: SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    key: const Key('repeat-minus'),
                    icon: const Icon(Icons.remove),
                    onPressed: () =>
                        setState(() => _count = _count > 1 ? _count - 1 : 1),
                  ),
                  Text(
                    '$_count',
                    key: const Key('repeat-value'),
                    style: const TextStyle(
                      fontFamily: AppFonts.digits,
                      fontSize: 22,
                      color: AppColors.text,
                    ),
                  ),
                  IconButton(
                    key: const Key('repeat-plus'),
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => _count++),
                  ),
                ],
              ),
              const Divider(),
              FocusRing(
                focused: _nav.isFocused('repeat-ok'),
                child: TextButton(
                  key: const Key('repeat-ok'),
                  onPressed: () => Navigator.of(context).pop(_count),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

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
  /// Live pass count; never drops below 1.
  late int _count = widget.initial < 1 ? 1 : widget.initial;

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              TextButton(
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
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/time_adjust_modal.dart';

/// Tweaks #7 — the "+/- time" menu: the active-box model (Enter/Shift+Enter
/// cycle, ↑/↓ toggle the sign or adjust by 1 / Ctrl by 10), Esc applies,
/// Shift+Esc cancels, and the dialog returns the signed delta in seconds.
void main() {
  int? result;

  Future<void> openModal(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open'),
              onPressed: () async {
                result = await showTimeAdjustModal(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    result = null;
  }

  testWidgets('opens_focused_on_the_sign_box', (tester) async {
    await openModal(tester);
    expect(
      tester.widget<TextField>(find.byKey(const Key('adjust-sign'))).focusNode!.hasFocus,
      isTrue,
    );
    expect(find.text('unset'), findsOneWidget);
  });

  testWidgets('enter_cycles_the_boxes', (tester) async {
    await openModal(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('adjust-hr'))).focusNode!.hasFocus,
      isTrue,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('adjust-sign'))).focusNode!.hasFocus,
      isTrue,
    );
  });

  testWidgets('arrows_toggle_sign_and_adjust_boxes', (tester) async {
    await openModal(tester);
    // Either arrow toggles the sign box (TWEAKS.md #7).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('adjust-sign'))).controller!.text,
      '-',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('adjust-sign'))).controller!.text,
      '+',
    );
    // Minutes: Up = +1, Ctrl+Up = +10.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // -> hr
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // -> min
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('adjust-min'))).controller!.text,
      '01',
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('adjust-min'))).controller!.text,
      '11',
    );
  });

  testWidgets('esc_applies_shift_esc_cancels', (tester) async {
    await openModal(tester);
    await tester.enterText(find.byKey(const Key('adjust-min')), '05');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(result, 0); // cancelled

    await openModal(tester);
    await tester.enterText(find.byKey(const Key('adjust-min')), '05');
    await tester.enterText(find.byKey(const Key('adjust-sign')), '-');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(result, -300); // applied: -5 min
  });

  testWidgets('apply_button_returns_the_signed_delta', (tester) async {
    await openModal(tester);
    await tester.enterText(find.byKey(const Key('adjust-hr')), '01');
    await tester.tap(find.byKey(const Key('adjust-apply')));
    await tester.pumpAndSettle();
    expect(result, 3600);
  });
}

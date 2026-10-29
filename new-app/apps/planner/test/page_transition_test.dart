import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/theme.dart';

/// The forward-route transition glitch fix: route pushes/pops are a plain
/// cross-fade — no zoom-builder SCRIM (the theme's semi-transparent surface
/// color washing over the whole window during forward pushes) and no
/// snapshot rasterization (whose stale composite froze behind the new
/// route until the next happenstance frame).
void main() {
  Widget screen(String label) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Center(child: Text(label)),
  );

  testWidgets('push_cross_fades_both_routes_without_scrim', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildPlannerTheme(), home: screen('A')),
    );

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(AppPageRoute<void>(builder: (_) => screen('B')));

    await tester.pump(); // transition starts
    await tester.pump(const Duration(milliseconds: 60)); // mid-flight (150ms total)

    // Both routes fade together: the outgoing one is still in the tree
    // (fading out), the incoming one is already fading in.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    // The zoom builder's scrim paints the theme's surface color
    // (AppColors.card) across the transition — none may exist.
    expect(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == AppColors.card),
      findsNothing,
      reason: 'the transition must not paint a surface scrim',
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pop_cross_fades_symmetrically', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildPlannerTheme(), home: screen('A')),
    );
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(AppPageRoute<void>(builder: (_) => screen('B')));
    await tester.pumpAndSettle();

    nav.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Same cross-fade shape as the push: both routes visible mid-flight.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == AppColors.card),
      findsNothing,
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('A'), findsOneWidget);
  });
}

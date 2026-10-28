import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planner/mock_board.dart';

void main() {
  Future<Finder> pumpBoard(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MockBoardPage()));
    return find.byType(MockBoardPage);
  }

  testWidgets('board renders top bar, dial readout, caption', (tester) async {
    await pumpBoard(tester);

    expect(find.text('tmp'), findsOneWidget); // board name
    // Dial readout: 03H:00M + subscript seconds.
    expect(find.text('03'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('00'), findsNWidgets(2)); // minutes + seconds
    // Next-interval caption (chevron rendered as icon + text).
    expect(find.text('1. break - 7m 30s'), findsOneWidget);
  });

  testWidgets('board renders the 6-button control row', (tester) async {
    await pumpBoard(tester);

    for (final key in const [
      Key('control-play'),
      Key('control-restart'),
      Key('control-pause'),
      Key('control-list'),
      Key('control-close'),
      Key('control-lock'),
    ]) {
      expect(find.byKey(key), findsOneWidget, reason: 'missing $key');
    }
    // Timer not started → pause disabled, others enabled.
    final pause = tester.widget<IconButton>(find.byKey(const Key('control-pause')));
    expect(pause.onPressed, isNull);
    final play = tester.widget<IconButton>(find.byKey(const Key('control-play')));
    expect(play.onPressed, isNotNull);
  });

  testWidgets('board renders chip list with group bracket', (tester) async {
    await pumpBoard(tester);

    expect(find.byKey(const Key('chip-Run')), findsOneWidget);
    expect(find.byKey(const Key('chip-break')), findsOneWidget);
    expect(find.byKey(const Key('chip-Cards')), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
    expect(find.text('break'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    // Durations use digits (right-aligned chip column).
    expect(find.text('50m'), findsOneWidget);
    expect(find.text('7m 30s'), findsOneWidget);
    expect(find.text('15m'), findsOneWidget);
    // Group repeat count badge + bracket glyph.
    expect(find.byKey(const Key('group-bracket')), findsOneWidget);
    expect(find.byKey(const Key('group-count')), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('board renders 3 page dots with the last active', (tester) async {
    await pumpBoard(tester);

    expect(find.byKey(const Key('page-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('page-dot-1')), findsOneWidget);
    expect(find.byKey(const Key('page-dot-2')), findsOneWidget);
    final active = tester.widget<Container>(find.byKey(const Key('page-dot-2')));
    final inactive = tester.widget<Container>(find.byKey(const Key('page-dot-0')));
    // Active dot filled, inactive ones hollow.
    expect((active.decoration as BoxDecoration).color, isNotNull);
    expect((inactive.decoration as BoxDecoration).color, isNull);
  });
}

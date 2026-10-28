import 'package:flutter_test/flutter_test.dart';

import 'package:planner/main.dart';
import 'package:planner/mock_board.dart';

void main() {
  testWidgets('PlannerApp boots into the mock board', (tester) async {
    await tester.pumpWidget(const PlannerApp());

    expect(find.byType(MockBoardPage), findsOneWidget);
    expect(find.text('tmp'), findsOneWidget); // board name
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/alert_selector.dart';

import 'fakes.dart';

/// Recording play fake that ALSO mirrors the desktop player's stop() hook —
/// AlertSelectorScreen widget tests (P4.3): row order ("No alert" first,
/// files alphabetical without the extension), the selection checkmark,
/// preview ▶ plus stop-on-selection-change, the null option, and the
/// empty-state path copy.
void main() {
  late RecordingPlayer player;
  late List<String?> selections;

  setUp(() {
    player = RecordingPlayer();
    selections = [];
  });

  /// Pumps the selector alone over the recording fake; [listing] feeds the
  /// rescan-on-open listing and [selected] seeds the incoming selection.
  Future<void> pumpSelector(
    WidgetTester tester, {
    List<String> listing = const ['zebra.mp3', 'alpha.mp3'],
    String? selected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlertSelectorScreen(
          soundsDir: '/sounds',
          soundListing: () => listing,
          player: player,
          selected: selected,
          onSelected: selections.add,
        ),
      ),
    );
  }

  // 11. "No alert" sits above the file rows, and the files come out
  //     alphabetical by name WITHOUT the extension (input is unsorted);
  //     labels drop `.mp3`.
  testWidgets('alert_rows_alphabetical_with_no_alert_first', (tester) async {
    await pumpSelector(tester, listing: ['zebra.mp3', 'alpha.mp3']);

    expect(find.byKey(const Key('as-none')), findsOneWidget);
    expect(find.text('No alert'), findsOneWidget);
    expect(find.byKey(const Key('as-row-alpha.mp3')), findsOneWidget);
    expect(find.byKey(const Key('as-row-zebra.mp3')), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('zebra'), findsOneWidget);

    final noneY = tester.getTopLeft(find.byKey(const Key('as-none'))).dy;
    final alphaY = tester
        .getTopLeft(find.byKey(const Key('as-row-alpha.mp3')))
        .dy;
    final zebraY = tester
        .getTopLeft(find.byKey(const Key('as-row-zebra.mp3')))
        .dy;
    expect(noneY, lessThan(alphaY), reason: "'No alert' sits above files");
    expect(alphaY, lessThan(zebraY), reason: 'files sort alphabetically');
  });

  // 12. The incoming selection shows its checkmark — on alpha only, never
  //     on the other rows or "No alert".
  testWidgets('default_selection_first_alphabetical', (tester) async {
    await pumpSelector(
      tester,
      listing: ['alpha.mp3', 'zebra.mp3'],
      selected: 'alpha.mp3',
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('as-row-alpha.mp3')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('as-row-zebra.mp3')),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('as-none')),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
  });

  // 13. ▶ previews the full path via the player; selecting a different
  //     row stops the running preview FIRST and reports the new pick (no
  //     auto-play on selection).
  testWidgets('preview_invoked_and_stops_on_change', (tester) async {
    await pumpSelector(
      tester,
      listing: ['alpha.mp3', 'beta.mp3'],
      selected: 'alpha.mp3',
    );

    await tester.tap(find.byKey(const Key('as-play-alpha.mp3')));
    await tester.pump();
    expect(player.played, ['/sounds/alpha.mp3']);

    await tester.tap(find.byKey(const Key('as-row-beta.mp3')));
    await tester.pump();
    expect(player.stopCount, 1); // stop FIRST, then the selection callback
    expect(selections, ['beta.mp3']);
  });

  // 14. "No alert" persists null through the selection callback.
  testWidgets('no_alert_option_persists_null', (tester) async {
    await pumpSelector(tester, listing: ['alpha.mp3'], selected: 'alpha.mp3');

    await tester.tap(find.byKey(const Key('as-none')));
    await tester.pump();

    expect(selections, [null]);
    expect(player.stopCount, 1); // the previous preview is cut too
  });

  // 15. Empty listing → the explanatory state, quoting the sounds path.
  testWidgets('empty_state_shows_path', (tester) async {
    await pumpSelector(tester, listing: const []);

    expect(find.byKey(const Key('as-empty')), findsOneWidget);
    expect(find.text('No sounds found'), findsOneWidget);
    expect(
      find.text('Drop .mp3 files into /sounds and reopen.'),
      findsOneWidget,
    );
  });
}

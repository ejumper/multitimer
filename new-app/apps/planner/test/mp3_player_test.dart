import 'package:flutter_test/flutter_test.dart';
import 'package:planner/adapters/mp3_player.dart';

/// Pins the path→URI contract at the GStreamer boundary: audioplayers'
/// Linux plugin hands the string to `playbin`'s "uri" property verbatim, so
/// the adapter must supply a proper `file://` URI (a bare path is rejected
/// as "Invalid URI" before the file is touched).
void main() {
  test('sound_file_uri_produces_file_scheme_uri', () {
    expect(
      soundFileUri('/home/u/.local/share/planner/sounds/ding.mp3'),
      'file:///home/u/.local/share/planner/sounds/ding.mp3',
    );
    expect(soundFileUri('/a/b c.mp3'), 'file:///a/b%20c.mp3');
  });
}

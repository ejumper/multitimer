import 'dart:io';

import 'package:test/test.dart';

/// Purity test (CONVENTIONS §2): `planner_engine` is pure Dart.
///
/// The engine must never import `dart:io` or anything Flutter. OS access
/// (clock, storage, notifications) is injected via interfaces defined in the
/// engine itself, so `lib/` has no reason to touch the outside world.
/// Trivially green today; load-bearing from P1.1 on.
void main() {
  final libDir = Directory('lib');
  final forbidden = RegExp(r'''^import\s+['"](dart:io|package:flutter)''');

  test('engine lib/ contains no dart:io or flutter imports', () async {
    expect(libDir.existsSync(), isTrue, reason: 'engine lib/ must exist');

    final offenders = <String>[];
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (final line in lines) {
        if (forbidden.hasMatch(line.trim())) {
          offenders.add('${entity.path}: $line');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'planner_engine must stay pure Dart — '
            'inject Clock/Store/sinks instead of importing dart:io/flutter:\n'
            '${offenders.join('\n')}');
  });
}

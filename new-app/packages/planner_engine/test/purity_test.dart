import 'dart:io';

import 'package:test/test.dart';

/// Purity test (CONVENTIONS §2): `planner_engine` is pure Dart.
///
/// The engine must never import `dart:io` outside `lib/storage/impl/` and
/// never import anything Flutter. OS access (clock, storage, notifications)
/// is injected via interfaces defined in the engine itself.
///
/// The single, documented exception: `lib/storage/impl/db_opener.dart` opens
/// the SQLite file the app points it at (P1.1 decision, recorded in the
/// report) — `dart:io` is allowed there and nowhere else in `lib/`.
void main() {
  final libDir = Directory('lib');
  final forbiddenIoOutsideImpl = RegExp(r'''^import\s+['"]dart:io['"]''');
  final forbiddenFlutter = RegExp(r'''^import\s+['"]package:flutter''');

  test('engine lib/ contains no flutter imports', () async {
    expect(libDir.existsSync(), isTrue, reason: 'engine lib/ must exist');

    final offenders = <String>[];
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final line in entity.readAsLinesSync()) {
        if (forbiddenFlutter.hasMatch(line.trim())) {
          offenders.add('${entity.path}: $line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'planner_engine must never import flutter:\n'
          '${offenders.join('\n')}',
    );
  });

  test('dart:io imports exist only in lib/storage/impl/', () async {
    final offenders = <String>[];
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      final inImpl = normalized.contains('/storage/impl/');
      for (final line in entity.readAsLinesSync()) {
        final isIoImport = forbiddenIoOutsideImpl.hasMatch(line.trim());
        if (isIoImport && !inImpl) {
          offenders.add('${entity.path}: $line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'dart:io is confined to storage/impl/ (documented exception) '
          '— inject Clock/Store/sinks instead:\n${offenders.join('\n')}',
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _webFirstExports = [
  'lib/core/platform/database_path.dart',
  'lib/core/platform/storage_factory.dart',
  'lib/core/platform/secure_kv_store.dart',
];

const _bannedInWebCompiledSources = [
  'package:path_provider/path_provider.dart',
  'getApplicationSupportDirectory(',
  'getApplicationDocumentsDirectory(',
  'getTemporaryDirectory(',
  'flutter_secure_storage_windows',
  'package:flutter_secure_storage/flutter_secure_storage.dart',
  "package:sqflite/sqflite.dart",
  "import 'dart:io'",
  'import "dart:io"',
];

void main() {
  test('web-compiled Dart never reaches native filesystem or plugin APIs', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);

    final violations = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('_io.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final needle in _bannedInWebCompiledSources) {
        if (source.contains(needle)) {
          violations.add('${entity.path}: $needle');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('conditional exports select web before dart.library.io', () {
    final condition = RegExp(r'if \(dart\.library\.(\w+)\)');
    for (final path in _webFirstExports) {
      final source = File(path).readAsStringSync();
      final libraries =
          condition.allMatches(source).map((match) => match.group(1)!).toList();
      expect(
        libraries,
        ['html', 'js_interop', 'js_util', 'io'],
        reason: path,
      );
    }
  });

  test('IO path lookup does not catch plugin failures', () {
    final source =
        File('lib/core/platform/database_path_io.dart').readAsStringSync();
    expect(source.contains('getApplicationSupportDirectory('), isTrue);
    expect(RegExp(r'\bcatch\s*\(').hasMatch(source), isFalse);
    expect(source.contains('MissingPluginException'), isFalse);
  });

  test('secure storage warm-up does not catch plugin failures', () {
    final source =
        File('lib/data/local/secure/secure_storage_service.dart').readAsStringSync();
    expect(RegExp(r'\bcatch\s*\(').hasMatch(source), isFalse);
    expect(source.contains('MissingPluginException'), isFalse);
  });
}

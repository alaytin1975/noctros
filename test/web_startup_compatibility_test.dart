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

bool _isNativeOnly(String path) {
  return path.endsWith('_io.dart') || path.endsWith('main_native.dart');
}

void main() {
  test('web-compiled Dart never reaches native filesystem or plugin APIs', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);

    final violations = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (_isNativeOnly(entity.path)) {
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

  test('Chrome entry imports web storage files only', () {
    final source = File('lib/main_web.dart').readAsStringSync();
    expect(source.contains('database_path_web.dart'), isTrue);
    expect(source.contains('storage_factory_web.dart'), isTrue);
    expect(source.contains('secure_kv_store_web.dart'), isTrue);
    expect(source.contains('main_native.dart'), isFalse);
    expect(source.contains('database_path_io.dart'), isFalse);
    expect(source.contains('path_provider'), isFalse);
  });

  test('web implementations are the default; IO is opt-in only', () {
    for (final path in [
      ..._webFirstExports,
      'lib/main.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source.contains("'main_web.dart'") || source.contains('_web.dart'), isTrue, reason: path);
      final firstExport = RegExp(r"export '([^']+)'").firstMatch(source);
      final firstImport = RegExp(r"import '([^']+)'").firstMatch(source);
      if (path == 'lib/main.dart') {
        expect(firstImport?.group(1), 'main_web.dart');
      } else if (path != 'lib/core/platform/secure_kv_store.dart') {
        expect(firstExport?.group(1), contains('_web.dart'), reason: path);
      }
      expect(source.contains('if (dart.library.io)'), isTrue, reason: path);
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

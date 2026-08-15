import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web-compiled Dart never calls path_provider APIs', () {
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
      for (final needle in const [
        'package:path_provider/path_provider.dart',
        'getApplicationSupportDirectory(',
        'getApplicationDocumentsDirectory(',
        'getTemporaryDirectory(',
      ]) {
        if (source.contains(needle)) {
          violations.add('${entity.path}: $needle');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

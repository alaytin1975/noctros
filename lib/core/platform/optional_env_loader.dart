import 'package:flutter/services.dart';

/// Optional env file. Missing `.env` must not stop Chrome startup.
abstract final class OptionalEnvLoader {
  static const _candidates = ['.env', 'assets/.env'];

  static Future<void> load() async {
    for (final key in _candidates) {
      try {
        await rootBundle.loadString(key);
        return;
      } catch (_) {
        continue;
      }
    }
  }
}

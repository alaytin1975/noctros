import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

/// One place that decides which SQLite backend Noctros uses and where the
/// database lives on disk. Called exactly once from [NoctrosBootstrap] before
/// any repository touches storage.
///
/// Platform matrix:
///   Windows / Linux : sqflite_common_ffi (bundled sqlite3), APPDATA/XDG dir.
///   macOS           : native sqflite plugin, ~/Library/Application Support.
///   iOS / Android   : native sqflite plugin, application support directory.
///   Web             : intentionally unsupported. A separate storage
///                     implementation must be provided before Noctros can
///                     boot in Chrome.
abstract final class PlatformStorage {
  static Future<String> initializeAndResolvePath({
    required String databaseName,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Noctros storage is native-only in this build. '
        'Run on Windows, macOS, Linux, iOS, or Android.',
      );
    }

    _configureSqfliteFactory();

    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, databaseName);
  }

  static void _configureSqfliteFactory() {
    // sqflite ships native plugins for Android, iOS, and macOS. Windows and
    // Linux desktop have no plugin, so their factory must come from FFI.
    if (Platform.isWindows || Platform.isLinux) {
      ffi.sqfliteFfiInit();
      sqflite.databaseFactory = ffi.databaseFactoryFfi;
    }
  }
}

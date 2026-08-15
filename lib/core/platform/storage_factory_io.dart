import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite_plugin;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Windows and Linux have no bundled sqflite plugin; use FFI there.
/// iOS, Android, and macOS keep the native sqflite plugin factory.
void configureStorageFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    return;
  }
  databaseFactory = sqflite_plugin.databaseFactorySqflitePlugin;
}

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Chrome/web has no path_provider application-support directory and no
/// native sqflite plugin. IndexedDB-backed sqlite3.wasm is used instead.
void configureStorageFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}

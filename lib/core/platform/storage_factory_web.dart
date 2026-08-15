import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Chrome/web uses sqlite3.wasm + IndexedDB. Native sqflite and path_provider
/// are not imported from this file.
void configureStorageFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}

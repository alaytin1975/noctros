import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Native database path for iOS, Android, macOS, Windows, and Linux.
///
/// This file is imported only by [main_native.dart]. Chrome compiles
/// [main_web.dart] instead, so this function is not part of the web graph.
Future<String> resolveNoctrosDatabasePath({
  required String? overridePath,
  required String databaseName,
}) async {
  if (overridePath != null) {
    return overridePath;
  }
  final directory = await getApplicationSupportDirectory();
  return p.join(directory.path, databaseName);
}

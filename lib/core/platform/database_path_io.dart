import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Native database path for iOS, Android, macOS, Windows, and Linux.
///
/// This file is never selected by a web compiler. Do not catch plugin
/// failures here; a missing path_provider plugin must surface immediately.
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

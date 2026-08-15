import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Future<String> resolveNoctrosDatabasePath({
  required String? overridePath,
  required String databaseName,
}) async {
  if (overridePath != null) {
    return overridePath;
  }
  try {
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, databaseName);
  } catch (_) {
    return p.join(await getDatabasesPath(), databaseName);
  }
}

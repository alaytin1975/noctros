import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap/noctros_bootstrap.dart';
import 'app/noctros_app.dart';
import 'core/platform/database_path_io.dart';
import 'core/platform/secure_kv_store_io.dart';
import 'core/platform/storage_factory_io.dart';

/// iOS, Android, macOS, Windows, and Linux entry.
/// Native filesystem and plugin storage stay here, off the Chrome graph.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NoctrosBootstrap.initialize(
    configureStorage: configureStorageFactory,
    resolveDatabasePath: resolveNoctrosDatabasePath,
    createSecureStore: createSecureKvStore,
  );

  runApp(
    const ProviderScope(
      child: NoctrosApp(),
    ),
  );
}

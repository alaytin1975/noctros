import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap/noctros_bootstrap.dart';
import 'app/noctros_app.dart';
import 'core/platform/database_path_web.dart';
import 'core/platform/secure_kv_store_web.dart';
import 'core/platform/storage_factory_web.dart';

/// Chrome / Flutter web entry. This file imports only browser-safe storage.
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

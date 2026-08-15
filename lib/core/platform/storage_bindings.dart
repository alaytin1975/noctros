import 'secure_kv_store_api.dart';

typedef DatabasePathResolver = Future<String> Function({
  required String? overridePath,
  required String databaseName,
});

typedef StorageConfigurator = void Function();

typedef SecureKvStoreFactory = SecureKvStore Function();

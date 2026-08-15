import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_kv_store_api.dart';

/// Native store for iOS, Android, macOS, Windows, and Linux.
///
/// This file is never selected by a web compiler, so
/// flutter_secure_storage_windows cannot enter the Chrome graph.
SecureKvStore createSecureKvStore() => _FlutterSecureKvStore();

class _FlutterSecureKvStore implements SecureKvStore {
  _FlutterSecureKvStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

import 'package:encrypt/encrypt.dart' as encrypt;

import '../../../core/platform/secure_kv_store_api.dart';

/// Wraps secure storage and provides encryption key management for local data.
class SecureStorageService {
  SecureStorageService({
    required SecureKvStore store,
  }) : _store = store;

  static const _encryptionKeyName = 'noctros_secure_db_key';

  final SecureKvStore _store;
  encrypt.Key? _databaseKey;

  Future<void> warmUp() async {
    _databaseKey = await _loadOrCreateDatabaseKey();
  }

  encrypt.Key get databaseKey {
    final key = _databaseKey;
    if (key == null) {
      throw StateError('SecureStorageService has not been initialized.');
    }
    return key;
  }

  Future<String?> read(String key) => _store.read(key);

  Future<void> write(String key, String value) => _store.write(key, value);

  Future<void> delete(String key) => _store.delete(key);

  Future<encrypt.Key> _loadOrCreateDatabaseKey() async {
    final existing = await _store.read(_encryptionKeyName);
    if (existing != null && existing.length == 32) {
      return encrypt.Key.fromUtf8(existing);
    }

    final generated = encrypt.Key.fromSecureRandom(32);
    await _store.write(
      _encryptionKeyName,
      String.fromCharCodes(generated.bytes),
    );
    return generated;
  }
}

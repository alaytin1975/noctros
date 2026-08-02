import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps secure storage and provides encryption key management for local data.
class SecureStorageService {
  SecureStorageService({
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

  static const _encryptionKeyName = 'noctros_secure_db_key';

  final FlutterSecureStorage _storage;
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

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<encrypt.Key> _loadOrCreateDatabaseKey() async {
    final existing = await _storage.read(key: _encryptionKeyName);
    if (existing != null && existing.length == 32) {
      return encrypt.Key.fromUtf8(existing);
    }

    final generated = encrypt.Key.fromSecureRandom(32);
    await _storage.write(
      key: _encryptionKeyName,
      value: String.fromCharCodes(generated.bytes),
    );
    return generated;
  }
}

/// Key-value store used for encryption-key material and small secrets.
abstract class SecureKvStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

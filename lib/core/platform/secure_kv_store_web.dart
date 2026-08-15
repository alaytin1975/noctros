import 'package:web/web.dart' as web;

import '../constants/noctros_constants.dart';
import 'secure_kv_store_api.dart';

/// Browser-safe store. Uses `window.localStorage` and never imports
/// flutter_secure_storage or path_provider.
SecureKvStore createSecureKvStore() => _BrowserLocalStorageKvStore();

class _BrowserLocalStorageKvStore implements SecureKvStore {
  static const _prefix = '${NoctrosConstants.secureStorageNamespace}:';

  web.Storage get _storage => web.window.localStorage;

  String _namespaced(String key) => '$_prefix$key';

  @override
  Future<String?> read(String key) async {
    return _storage.getItem(_namespaced(key));
  }

  @override
  Future<void> write(String key, String value) async {
    _storage.setItem(_namespaced(key), value);
  }

  @override
  Future<void> delete(String key) async {
    _storage.removeItem(_namespaced(key));
  }
}

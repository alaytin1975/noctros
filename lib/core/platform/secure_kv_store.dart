export 'secure_kv_store_api.dart';

// Web libraries are tested first. First match wins, so Chrome cannot import
// native secure-storage or Windows DPAPI filesystem backends.
export 'secure_kv_store_stub.dart'
    if (dart.library.html) 'secure_kv_store_web.dart'
    if (dart.library.js_interop) 'secure_kv_store_web.dart'
    if (dart.library.js_util) 'secure_kv_store_web.dart'
    if (dart.library.io) 'secure_kv_store_io.dart';

export 'secure_kv_store_api.dart';

// Flutter web always has dart:ui_web. That condition is first so Chrome
// cannot bind native secure-storage backends.
export 'secure_kv_store_web.dart'
    if (dart.library.ui_web) 'secure_kv_store_web.dart'
    if (dart.library.html) 'secure_kv_store_web.dart'
    if (dart.library.js_interop) 'secure_kv_store_web.dart'
    if (dart.library.js_util) 'secure_kv_store_web.dart'
    if (dart.library.io) 'secure_kv_store_io.dart';

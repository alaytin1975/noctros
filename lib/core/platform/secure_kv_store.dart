export 'secure_kv_store_api.dart';

// Web is the default. dart.library.io is not a web conditional-import
// (support_conditional_import: false on dart2js/DDC).
export 'secure_kv_store_web.dart'
    if (dart.library.io) 'secure_kv_store_io.dart';

// Flutter web always has dart:ui_web. That condition is first so Chrome
// cannot bind the path_provider implementation.
export 'database_path_web.dart'
    if (dart.library.ui_web) 'database_path_web.dart'
    if (dart.library.html) 'database_path_web.dart'
    if (dart.library.js_interop) 'database_path_web.dart'
    if (dart.library.js_util) 'database_path_web.dart'
    if (dart.library.io) 'database_path_io.dart';

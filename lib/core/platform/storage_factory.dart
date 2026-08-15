// Flutter web always has dart:ui_web. That condition is first so Chrome
// cannot bind the dart:io / native sqflite implementation.
export 'storage_factory_web.dart'
    if (dart.library.ui_web) 'storage_factory_web.dart'
    if (dart.library.html) 'storage_factory_web.dart'
    if (dart.library.js_interop) 'storage_factory_web.dart'
    if (dart.library.js_util) 'storage_factory_web.dart'
    if (dart.library.io) 'storage_factory_io.dart';

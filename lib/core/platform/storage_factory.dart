// Web libraries are tested first. First match wins, so Chrome cannot bind
// the dart:io FFI / native sqflite implementation.
export 'storage_factory_stub.dart'
    if (dart.library.html) 'storage_factory_web.dart'
    if (dart.library.js_interop) 'storage_factory_web.dart'
    if (dart.library.js_util) 'storage_factory_web.dart'
    if (dart.library.io) 'storage_factory_io.dart';

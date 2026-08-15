// Selects the sqflite factory. Web conditions come first so Chrome never
// compiles the dart:io FFI path, even if dart.library.io is also defined.
export 'storage_factory_stub.dart'
    if (dart.library.html) 'storage_factory_web.dart'
    if (dart.library.js_interop) 'storage_factory_web.dart'
    if (dart.library.io) 'storage_factory_io.dart';

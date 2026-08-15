// Platform database path. Web is selected first so Chrome never links
// path_provider, even if dart:io stubs exist in the web compiler.
export 'database_path_stub.dart'
    if (dart.library.html) 'database_path_web.dart'
    if (dart.library.js_interop) 'database_path_web.dart'
    if (dart.library.io) 'database_path_io.dart';

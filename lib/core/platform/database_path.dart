// Web libraries are tested first. First match wins, so Chrome cannot bind
// the IO/path_provider implementation even if dart.library.io is also defined.
export 'database_path_stub.dart'
    if (dart.library.html) 'database_path_web.dart'
    if (dart.library.js_interop) 'database_path_web.dart'
    if (dart.library.js_util) 'database_path_web.dart'
    if (dart.library.io) 'database_path_io.dart';

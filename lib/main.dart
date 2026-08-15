import 'main_native.dart' as impl
    if (dart.library.ui_web) 'main_web.dart'
    if (dart.library.html) 'main_web.dart'
    if (dart.library.js_interop) 'main_web.dart'
    if (dart.library.js_util) 'main_web.dart';

/// Flutter web compilers always provide [dart:ui_web] (see the generated
/// `web_entrypoint` that imports it). That condition is checked first so
/// Chrome binds the browser entry and never the native filesystem entry.
Future<void> main() => impl.main();

import 'main_web.dart' as impl
    if (dart.library.io) 'main_native.dart';

/// Web is the default library. `dart.library.io` is marked
/// `support_conditional_import: false` on dart2js and DDC, so Chrome keeps
/// [main_web.dart]. The VM/native compilers do support that condition and
/// bind [main_native.dart].
Future<void> main() => impl.main();

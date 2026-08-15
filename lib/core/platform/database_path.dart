// Web is the default. dart.library.io is not a web conditional-import
// (support_conditional_import: false on dart2js/DDC).
export 'database_path_web.dart'
    if (dart.library.io) 'database_path_io.dart';

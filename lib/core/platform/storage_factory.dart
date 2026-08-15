// Web is the default. dart.library.io is not a web conditional-import
// (support_conditional_import: false on dart2js/DDC).
export 'storage_factory_web.dart'
    if (dart.library.io) 'storage_factory_io.dart';

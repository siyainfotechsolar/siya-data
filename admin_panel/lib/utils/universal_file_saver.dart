export 'universal_file_saver_stub.dart'
    if (dart.library.js_interop) 'universal_file_saver_web.dart'
    if (dart.library.html) 'universal_file_saver_web.dart';


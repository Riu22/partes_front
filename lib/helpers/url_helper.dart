/// Este archivo elige automáticamente el helper para obtener la URL actual
/// según la plataforma:
///   - En web usa url_helper_web.dart
///   - En otras plataformas usa url_helper_stub.dart

export 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart';

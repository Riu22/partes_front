/// Este archivo elige automáticamente el helper para ocultar la pantalla
/// de bienvenida (splash) según la plataforma:
///   - En web usa splash_helper_web.dart
///   - En otras plataformas usa splash_helper_stub.dart

export 'splash_helper_stub.dart'
    if (dart.library.js) 'splash_helper_web.dart';

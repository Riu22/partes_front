/// Este archivo elige automáticamente el helper de captura de pantalla
/// según la plataforma donde se ejecute la app:
///   - En web usa el archivo capture_helper_web.dart
///   - En móvil (Android/iOS) usa capture_helper_mobile.dart
///
/// Las pantallas solo deben importar este archivo, no los específicos de cada plataforma.

export 'capture_helper_mobile.dart'
    if (dart.library.html) 'capture_helper_web.dart';

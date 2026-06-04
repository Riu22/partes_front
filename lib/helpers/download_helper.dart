/// Este archivo elige automáticamente el helper de descarga de archivos
/// según la plataforma donde se ejecute la app:
///   - En web usa el archivo download_helper_web.dart
///   - En escritorio (Windows, Linux, macOS) usa download_helper_desktop.dart
///   - En otras plataformas usa download_helper_stub.dart

export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_desktop.dart';

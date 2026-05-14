// capture_helper.dart
// Enruta automáticamente al helper correcto según la plataforma:
//   - Web   → capture_helper_web.dart   (dart:html, sin path_provider)
//   - Móvil → capture_helper_mobile.dart (stub; lanza UnimplementedError)
//
// En contabilidad_screen.dart importa SOLO este fichero:
//   import 'capture_helper.dart';

export 'capture_helper_mobile.dart'
    if (dart.library.html) 'capture_helper_web.dart';

/// Versión de respaldo (stub) para obtener la URL actual.
/// En plataformas que no son web devuelve la URL que se le pase como fallback.
/// Si se ejecuta en web (que no debería), intenta llamar a la versión web
/// pero lanza un error porque no está implementada aquí.

// ignore: avoid_web_libraries_in_flutter
import 'package:flutter/foundation.dart';

/// Obtiene la URL actual de la página.
///
/// - [fallback]: URL que se devuelve si no se puede obtener la real
/// Devuelve la URL actual como texto
String getCurrentUrl(Uri fallback) {
  if (kIsWeb) {
    return _getWebUrl();
  }
  return fallback.toString();
}

/// Intenta obtener la URL desde el navegador.
/// Esta función está aquí solo para que la app compile;
/// la implementación real está en url_helper_web.dart.
String _getWebUrl() {
  throw UnsupportedError('No implementado');
}

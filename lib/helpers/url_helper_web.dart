/// Versión para web del helper de URL.
/// Obtiene la dirección (URL) de la página actual desde el navegador.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Devuelve la URL completa de la página web donde se está ejecutando la app.
///
/// - [fallback]: esta versión ignora el fallback y siempre usa la URL real
/// Devuelve la URL actual como texto (ej. "https://ejemplo.com/partes")
String getCurrentUrl(Uri fallback) {
  return html.window.location.href;
}

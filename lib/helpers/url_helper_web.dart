// =============================================================================
//  url_helper_web.dart  -  HELPER DE URL (VERSION WEB)
// =============================================================================
//  QUE HACE ESTE ARCHIVO?
//  Proporciona la implementacion del helper que obtiene la URL actual
//  de la pagina web donde se ejecuta la aplicacion. En la web, la
//  URL esta disponible a traves de la API del navegador (window.location).
//  Esto es util para, por ejemplo, construir enlaces de API, compartir
//  la URL actual, o redirigir al usuario.
//
//  POR QUE LA WEB NECESITA SU PROPIA VERSION?
//  - La web tiene acceso a html.window.location.href, que devuelve
//    la URL completa de la pagina actual en el navegador. Esto solo
//    esta disponible cuando se ejecuta en un contexto de navegador
//    (dart:html).
//  - En movil y escritorio no existe el concepto de "pagina actual"
//    porque la aplicacion no se ejecuta en un navegador. En esas
//    plataformas se usa una URL de fallback.
//  - dart:html solo esta disponible en navegadores web, por lo que
//    esta implementacion no podria compilar en movil o escritorio.
//
//  CONTRATO:
//  Sigue la misma firma que la version stub:
//    String getCurrentUrl(Uri fallback)
//  Aunque aqui el parametro [fallback] se ignora, la firma debe
//  coincidir para que el export condicional funcione correctamente.
// =============================================================================

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // API del navegador (window.location)

/// Devuelve la URL completa de la pagina web donde se esta ejecutando
/// la aplicacion Flutter.
///
/// La URL se obtiene de html.window.location.href, que incluye
/// protocolo, dominio, puerto, ruta y parametros de consulta.
/// Ejemplo: "https://ejemplo.com/partes?id=123"
///
/// El parametro [fallback] se ignora en esta implementacion porque
/// siempre se puede obtener la URL real desde el navegador.
///
/// Parametros:
///   [fallback] - URL alternativa (se ignora en web porque siempre
///                tenemos acceso a la URL real del navegador).
///
/// Devuelve la URL actual como String.
String getCurrentUrl(Uri fallback) {
  // Accedemos a la propiedad href de window.location, que contiene
  // la URL completa de la pagina actual. Esto incluye:
  //   - Protocolo (https:)
  //   - Host (ejemplo.com)
  //   - Puerto (:8080 si no es el estandar)
  //   - Ruta (/partes)
  //   - Query string (?id=123)
  //   - Hash (#section)
  return html.window.location.href;
}

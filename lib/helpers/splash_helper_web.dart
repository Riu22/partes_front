// =============================================================================
//  splash_helper_web.dart  -  HELPER DE SPLASH (VERSION WEB)
// =============================================================================
//  QUE HACE ESTE ARCHIVO?
//  Proporciona la implementacion del helper que oculta la pantalla de
//  bienvenida (splash screen) en la plataforma web. En web, el splash
//  es un elemento HTML que se muestra antes de que Flutter cargue
//  completamente. Una vez que Flutter esta listo, hay que ocultarlo
//  llamando a una funcion JavaScript especifica.
//
//  POR QUE LA WEB NECESITA SU PROPIA VERSION?
//  - La web muestra un splash HTML/CSS personalizado en la pagina
//    antes de que Flutter se inicie (mientras se descargan los
//    assets y se compila el codigo Dart).
//  - Una vez que Flutter ha cargado, debe llamar a una funcion
//    JavaScript (hideSplash) para ocultar ese splash de forma
//    elegante (tipicamente con una transicion CSS).
//  - dart:js permite acceder al contexto global de JavaScript
//    del navegador y llamar a funciones definidas en el HTML.
//  - En movil y escritorio no es necesario porque el splash lo
//    maneja el sistema operativo.
//
//  CONTRATO:
//  Sigue la misma firma que la version stub:
//    void ocultarSplash()
// =============================================================================

import 'dart:js' as js; // Interoperabilidad con JavaScript en el navegador

/// Oculta la pantalla de bienvenida (splash screen) en la web.
///
/// Llama a la funcion `hideSplash()` que debe estar definida en el
/// codigo JavaScript de la pagina HTML que aloja la aplicacion
/// Flutter. Esta funcion tipicamente anade una clase CSS para
/// aplicar una transicion de desvanecimiento y luego elimina el
/// elemento del DOM.
///
/// Si la funcion `hideSplash` no existe en el contexto de JavaScript
/// (por ejemplo, si se cambio el HTML y se elimino esa funcion),
/// esta llamada no hace nada para evitar errores.
void ocultarSplash() {
  // Verificamos si la funcion hideSplash existe en el contexto
  // global de JavaScript (js.context). Esto evita errores si el
  // HTML que aloja la app no define esa funcion.
  if (js.context.hasProperty('hideSplash')) {
    // Si existe, la llamamos. Esto ocultara el elemento del splash
    // que se muestra mientras Flutter carga.
    js.context.callMethod('hideSplash');
  }
  // Si no existe, simplemente no hacemos nada. El splash HTML
  // seguira visible, pero Flutter se mostrara encima.
}

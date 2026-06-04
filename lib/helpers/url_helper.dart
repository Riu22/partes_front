// =============================================================================
//  url_helper.dart  -  HELPER DE OBTENCION DE URL (SELECTOR DE PLATAFORMA)
// =============================================================================
//  QUE ES UN HELPER?
//  En esta aplicacion, un "helper" es una herramienta o modulo ligero que
//  encapsula una funcionalidad especifica (descargar archivos, capturar
//  pantallas, obtener la URL, etc.) y la expone mediante una interfaz
//  simple. Los helpers se encargan de los detalles de implementacion
//  para que el resto de la aplicacion no tenga que preocuparse por
//  las diferencias entre plataformas (web, movil, escritorio).
//
//  QUE HACE ESTE ARCHIVO?
//  Es el punto de entrada para el helper que obtiene la URL actual
//  de la pagina donde se ejecuta la aplicacion. NO contiene logica
//  propia. Su unica responsabilidad es elegir automaticamente la
//  implementacion correcta segun la plataforma, usando las directivas
//  condicionales de Dart (export condicional).
//
//  CONTRATO (interfaz):
//  Este archivo define implicitamente el "contrato" que todas las
//  implementaciones deben seguir. El contrato es la funcion:
//    String getCurrentUrl(Uri fallback)
//  Cada implementacion (web, stub) debe proporcionar esta funcion
//  con la misma firma. El resto de la aplicacion solo llama a
//  getCurrentUrl sin saber en que plataforma se esta ejecutando.
//
//  POR QUE CADA PLATAFORMA NECESITA SU PROPIA VERSION?
//  - Web:       puede acceder a html.window.location.href para obtener
//               la URL completa de la pagina del navegador.
//  - Stub:      en movil y escritorio no hay "URL actual" porque la app
//               no se ejecuta en un navegador. La funcion devuelve una
//               URL de fallback que se pasa como parametro.
//
//  USO:
//    Las pantallas solo deben importar este archivo, no los especificos
//    de cada plataforma. Dart se encarga de resolver la exportacion
//    correcta en tiempo de compilacion.
// =============================================================================

// Exporta el helper de URL para la plataforma actual.
// Dart usa la primera linea que coincida con la condicion:
//   - Si existe dart.library.html (navegador web) -> url_helper_web.dart
//   - Si NO existe dart.library.html (movil/escritorio) -> url_helper_stub.dart
// Las condiciones se evaluan en tiempo de compilacion, no en ejecucion.
export 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart';

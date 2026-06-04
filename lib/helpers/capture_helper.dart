// =============================================================================
//  capture_helper.dart  -  HELPER DE CAPTURA DE PANTALLA (SELECTOR DE PLATAFORMA)
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
//  Es el punto de entrada para el helper de captura de pantalla.
//  NO contiene logica propia. Su unica responsabilidad es elegir
//  automaticamente la implementacion correcta segun la plataforma
//  donde se ejecute la aplicacion, usando directamente las directivas
//  condicionales de Dart (export condicional).
//
//  POR QUE CADA PLATAFORMA NECESITA SU PROPIA VERSION?
//  - Web:       puede usar dart:html para crear blobs y descargar
//               archivos (PDF) directamente en el navegador.
//  - Movil:     Android/iOS no tienen dart:html, y la generacion de
//               PDF no esta implementada aun, por lo que solo lanza
//               un error informativo.
//  - Escritorio: no hay implementacion propia; se usaria la de movil
//                o se crearia una especifica si hiciera falta.
//
//  USO:
//    Las pantallas solo deben importar este archivo, no los especificos
//    de cada plataforma. Dart se encarga de resolver la exportacion
//    correcta en tiempo de compilacion.
// =============================================================================

// Exporta el helper de captura de pantalla para la plataforma actual.
// Dart usa la primera linea que coincida con la condicion:
//   - Si existe dart.library.html (navegador web) -> capture_helper_web.dart
//   - Si NO existe dart.library.html (movil/escritorio) -> capture_helper_mobile.dart
// Las condiciones se evaluan en tiempo de compilacion, no en ejecucion.
export 'capture_helper_mobile.dart'
    if (dart.library.html) 'capture_helper_web.dart';

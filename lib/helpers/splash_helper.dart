// =============================================================================
//  splash_helper.dart  -  HELDER DE PANTALLA DE BIENVENIDA (SELECTOR DE PLATAFORMA)
// =============================================================================
//  QUE ES UN HELPER?
//  En esta aplicacion, un "helper" es una herramienta o modulo ligero que
//  encapsula una funcionalidad especifica (descargar archivos, ocultar la
//  pantalla de bienvenida, obtener la URL, etc.) y la expone mediante una
//  interfaz simple. Los helpers se encargan de los detalles de implementacion
//  para que el resto de la aplicacion no tenga que preocuparse por las
//  diferencias entre plataformas.
//
//  QUE HACE ESTE ARCHIVO?
//  Es el punto de entrada para el helper que oculta la pantalla de
//  bienvenida (splash screen). NO contiene logica propia. Su unica
//  responsabilidad es elegir automaticamente la implementacion correcta
//  segun la plataforma, usando las directivas condicionales de Dart.
//
//  CONTRATO (interfaz):
//  Este archivo define implicitamente el "contrato" que todas las
//  implementaciones deben seguir. El contrato es la funcion:
//    void ocultarSplash()
//  Cada implementacion (web, stub) debe proporcionar esta funcion
//  con la misma firma.
//
//  POR QUE CADA PLATAFORMA NECESITA SU PROPIA VERSION?
//  - Web:       necesita llamar a una funcion JavaScript (hideSplash)
//               para ocultar el splash HTML que se muestra antes de
//               que Flutter cargue completamente. Usa dart:js.
//  - Stub:      en movil y escritorio, Flutter maneja el splash de
//               forma nativa y no se necesita hacer nada especial.
//               El stub es una funcion vacia que no hace nada.
//
//  USO:
//    Las pantallas solo deben importar este archivo, no los especificos
//    de cada plataforma. Dart se encarga de resolver la exportacion
//    correcta en tiempo de compilacion.
// =============================================================================

// Exporta el helper de splash para la plataforma actual.
// Dart usa la primera linea que coincida con la condicion:
//   - Si existe dart.library.js (navegador web) -> splash_helper_web.dart
//   - Si NO existe dart.library.js (movil/escritorio) -> splash_helper_stub.dart
// Las condiciones se evaluan en tiempo de compilacion, no en ejecucion.
export 'splash_helper_stub.dart'
    if (dart.library.js) 'splash_helper_web.dart';

// =============================================================================
//  download_helper.dart  -  HELPER DE DESCARGA DE ARCHIVOS (SELECTOR DE PLATAFORMA)
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
//  Es el punto de entrada para el helper de descarga de archivos.
//  NO contiene logica propia. Su unica responsabilidad es elegir
//  automaticamente la implementacion correcta segun la plataforma
//  donde se ejecute la aplicacion, usando directamente las directivas
//  condicionales de Dart (export condicional).
//
//  CONTRATO (interfaz):
//  Este archivo define implicitamente el "contrato" que todas las
//  implementaciones deben seguir. El contrato es la funcion:
//    void saveAndLaunchFile(Uint8List bytes, String fileName)
//  Cada implementacion (web, desktop, stub) debe proporcionar esta
//  funcion con la misma firma. El resto de la aplicacion solo llama
//  a saveAndLaunchFile sin saber en que plataforma se esta ejecutando.
//
//  POR QUE CADA PLATAFORMA NECESITA SU PROPIA VERSION?
//  - Web:       usa dart:html para crear un Blob y descargar el archivo
//               a traves del navegador (dialogo de descarga nativo).
//  - Escritorio: usa dart:io y path_provider para guardar el archivo
//                en la carpeta de Descargas del sistema operativo.
//  - Stub:      para otras plataformas (o como fallback), solo imprime
//               un mensaje en la consola indicando que no esta soportado.
//
//  USO:
//    Las pantallas solo deben importar este archivo, no los especificos
//    de cada plataforma. Dart se encarga de resolver la exportacion
//    correcta en tiempo de compilacion.
// =============================================================================

// Exporta el helper de descarga para la plataforma actual.
// Dart usa la primera linea que coincida con la condicion:
//   1. Si existe dart.library.html (navegador web) -> download_helper_web.dart
//   2. Si existe dart.library.io (escritorio: Windows, Linux, macOS) -> download_helper_desktop.dart
//   3. Si ninguna coincide (otras plataformas) -> download_helper_stub.dart
// Las condiciones se evaluan en tiempo de compilacion, no en ejecucion.
export 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_desktop.dart';

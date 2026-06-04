// =============================================================================
//  download_helper_stub.dart  -  HELPER DE DESCARGA (VERSION STUB / RELLENO)
// =============================================================================
//  QUE HACE ESTE ARCHIVO?
//  Proporciona una implementacion de "relleno" (stub) del helper de
//  descarga de archivos para plataformas donde la funcionalidad no
//  esta implementada o no es aplicable. Simplemente imprime un
//  mensaje en la consola indicando que la descarga no esta soportada.
//
//  POR QUE ES NECESARIO UN STUB?
//  En Dart, cuando se usa export condicional (ver download_helper.dart),
//  T O D A S las plataformas deben tener una implementacion disponible
//  en tiempo de compilacion. El stub sirve como "plan B" para aquellas
//  plataformas que no sean web ni escritorio (ej. ciertos dispositivos
//  embebidos o plataformas experimentales).
//
//  CONTRATO:
//  Sigue la misma firma que las versiones web y desktop para mantener
//  la interfaz unificada. El resto de la aplicacion no nota la
//  diferencia porque todas usan el mismo nombre de funcion: saveAndLaunchFile.
// =============================================================================

import 'dart:typed_data'; // Uint8List para mantener la misma firma

/// Intenta guardar un archivo en la plataforma actual.
///
/// Esta implementacion (stub) no hace nada real. Solo imprime un
/// mensaje en la consola indicando que la descarga no esta
/// implementada para esta plataforma.
///
/// Parametros:
///   [bytes]    - El contenido del archivo (se ignora en el stub).
///   [fileName] - El nombre del archivo (se ignora en el stub).
void saveAndLaunchFile(Uint8List bytes, String fileName) {
  // Mensaje informativo en la consola. No se guarda ningun archivo.
  print("Descarga no implementada para esta plataforma");
}

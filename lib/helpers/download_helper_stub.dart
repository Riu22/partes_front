/// Versión de relleno (stub) para plataformas donde la descarga
/// no está implementada. Solo muestra un mensaje en la consola.

import 'dart:typed_data';

/// Intenta guardar un archivo, pero esta plataforma no lo soporta.
/// Solo imprime un aviso en la consola.
///
/// - [bytes]: el contenido del archivo
/// - [fileName]: el nombre del archivo
void saveAndLaunchFile(Uint8List bytes, String fileName) {
  print("Descarga no implementada para esta plataforma");
}

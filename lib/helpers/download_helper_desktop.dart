/// Versión para ordenador (Windows, Linux, macOS) del helper de descarga.
/// Guarda un archivo en la carpeta de Descargas del usuario.

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Guarda un archivo en el ordenador y muestra un mensaje con la ruta.
///
/// - [bytes]: el contenido del archivo como datos binarios
/// - [fileName]: el nombre que tendrá el archivo (ej. "datos.csv")
void saveAndLaunchFile(Uint8List bytes, String fileName) async {
  Directory? directory = await getDownloadsDirectory();
  directory ??= await getApplicationDocumentsDirectory();

  final String fullPath = '${directory.path}/$fileName';
  final File file = File(fullPath);

  await file.writeAsBytes(bytes);

  print("Archivo guardado en: $fullPath");
}

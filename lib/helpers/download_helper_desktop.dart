import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

void saveAndLaunchFile(Uint8List bytes, String fileName) async {
  // Obtenemos la ruta de descargas o documentos del usuario
  Directory? directory = await getDownloadsDirectory();
  directory ??= await getApplicationDocumentsDirectory();

  final String fullPath = '${directory.path}/$fileName';
  final File file = File(fullPath);

  await file.writeAsBytes(bytes);

  print("Archivo guardado en: $fullPath");
  // Opcional: Podrías usar el paquete 'url_launcher' para abrir la carpeta automáticamente
}

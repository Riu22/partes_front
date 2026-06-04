// =============================================================================
//  download_helper_desktop.dart  -  HELPER DE DESCARGA (VERSION ESCRITORIO)
// =============================================================================
//  QUE HACE ESTE ARCHIVO?
//  Proporciona la implementacion del helper de descarga de archivos
//  para plataformas de escritorio (Windows, Linux y macOS).
//  Guarda el archivo en la carpeta de Descargas del usuario o, si
//  no se puede acceder a ella, en la carpeta de documentos de la
//  aplicacion.
//
//  Por ahora solo imprime la ruta por consola. En el futuro se podria
//  mostrar un dialigo de "guardar como" nativo o una notificacion.
//
//  POR QUE EL ESCRITORIO NECESITA SU PROPIA VERSION?
//  - Escritorio: tiene acceso al sistema de archivos local a traves
//                de dart:io (File, Directory). Puede usar paquetes
//                como path_provider para encontrar directorios
//                estandar del sistema operativo.
//  - Web:        no tiene acceso al sistema de archivos local; usa
//                Blob y el dialogo de descarga del navegador.
//  - Stub:       para plataformas sin implementacion real.
// =============================================================================

import 'dart:io';              // Clases File, Directory para IO local
import 'dart:typed_data';       // Uint8List para datos binarios
import 'package:path_provider/path_provider.dart'; // Directorios del sistema

/// Guarda un archivo en el ordenador (carpeta de Descargas) y muestra
/// un mensaje en la consola con la ruta completa donde se guardo.
///
/// Si la carpeta de Descargas no esta disponible (por ejemplo, en
/// algunos entornos restringidos), usa la carpeta de documentos de
/// la aplicacion como alternativa.
///
/// Parametros:
///   [bytes]    - El contenido del archivo como datos binarios.
///                Generalmente viene de convertir un objeto a bytes
///                (ej. CSV, PDF, etc.).
///   [fileName] - El nombre que tendra el archivo al guardarse,
///                incluyendo la extension (ej. "datos.csv").
void saveAndLaunchFile(Uint8List bytes, String fileName) async {
  // Intentamos obtener la carpeta de Descargas del sistema.
  // En Windows es "C:\Users\<usuario>\Downloads"
  // En Linux es "/home/<usuario>/Downloads"
  // En macOS es "/Users/<usuario>/Downloads"
  Directory? directory = await getDownloadsDirectory();

  // Si no se pudo obtener la carpeta de Descargas (fallback),
  // usamos la carpeta de documentos de la aplicacion.
  directory ??= await getApplicationDocumentsDirectory();

  // Construimos la ruta completa del archivo.
  final String fullPath = '${directory.path}/$fileName';

  // Creamos un objeto File con la ruta y escribimos los bytes.
  // Si el archivo ya existe, se sobrescribe.
  final File file = File(fullPath);
  await file.writeAsBytes(bytes);

  // Mostramos la ruta por consola para que el usuario sepa donde
  // se guardo el archivo. En produccion se podria mostrar un
  // SnackBar o abrir el Explorador de Archivos.
  print("Archivo guardado en: $fullPath");
}

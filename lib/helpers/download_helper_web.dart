// =============================================================================
//  download_helper_web.dart  -  HELPER DE DESCARGA (VERSION WEB)
// =============================================================================
//  QUE HACE ESTE ARCHIVO?
//  Proporciona la implementacion del helper de descarga de archivos
//  para la plataforma web. Descarga un archivo directamente en el
//  navegador del usuario creando un Blob, generando una URL temporal
//  y simulando un clic en un enlace de descarga.
//
//  POR QUE LA WEB NECESITA SU PROPIA VERSION?
//  - La web no tiene acceso al sistema de archivos local como el
//    escritorio. En lugar de eso, usa la API del navegador (Blob,
//    URL.createObjectUrl, AnchorElement) para iniciar la descarga.
//  - El navegador se encarga de mostrar el dialogo de "Guardar como"
//    y de manejar la descarga real.
//  - dart:html solo esta disponible en navegadores web, por lo que
//    esta implementacion no podria compilar en movil o escritorio.
//
//  CONTRATO:
//  Sigue la misma firma que las versiones desktop y stub:
//    void saveAndLaunchFile(Uint8List bytes, String fileName)
// =============================================================================

import 'dart:html' as html;   // API del navegador (Blob, AnchorElement)
import 'dart:typed_data';      // Uint8List para datos binarios

/// Descarga un archivo en el navegador del usuario.
///
/// Crea un objeto Blob con los datos binarios, genera una URL
/// temporal que apunta a ese Blob, crea un elemento <a> invisible,
/// asigna la URL y el nombre de archivo, y simula un clic para
/// que el navegador muestre el dialogo de descarga.
///
/// Parametros:
///   [bytes]    - El contenido del archivo como datos binarios.
///                Puede ser CSV, PDF, JSON, etc.
///   [fileName] - El nombre con el que se guardara el archivo,
///                incluyendo la extension (ej. "datos.csv").
void saveAndLaunchFile(Uint8List bytes, String fileName) {
  // Creamos un Blob con los bytes. El tipo MIME es text/csv porque
  // esta funcion se usa principalmente para descargar archivos CSV
  // de partes de trabajo. Si se necesitara otro tipo, habria que
  // hacerlo parametrizable.
  final blob = html.Blob([bytes], 'text/csv');

  // Generamos una URL unica (blob:http://...) que apunta al Blob.
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Creamos un elemento <a> (enlace) invisible.
  final anchor = html.AnchorElement(href: url)

    // Anyadimos el atributo "download" con el nombre del archivo.
    // Esto hace que el navegador muestre el dialogo de "Guardar como"
    // en lugar de navegar a la URL.
    ..setAttribute("download", fileName)

    // Simulamos un clic en el enlace para iniciar la descarga.
    ..click();

  // Liberamos la URL temporal para que el recolector de basura
  // del navegador pueda liberar la memoria del Blob. No esperamos
  // a que la descarga termine porque el navegador ya tiene una
  // referencia al Blob a traves del enlace.
  html.Url.revokeObjectUrl(url);
}

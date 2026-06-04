/// Versión para web del helper de descarga.
/// Descarga un archivo directamente en el navegador usando dart:html.

import 'dart:html' as html;
import 'dart:typed_data';

/// Descarga un archivo en el navegador (se abre el diálogo de descarga).
///
/// - [bytes]: el contenido del archivo como datos binarios
/// - [fileName]: el nombre con el que se guardará el archivo
void saveAndLaunchFile(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

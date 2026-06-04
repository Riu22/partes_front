// =============================================================================
//  capture_helper_mobile.dart  -  HELPER DE CAPTURA (VERSION MOVIL)
// =============================================================================
//  QUE HACE ESTE ARCHIVO?
//  Proporciona la implementacion del helper de captura de pantalla
//  para dispositivos moviles (Android e iOS). En estas plataformas,
//  la generacion de PDF aun no esta implementada, por lo que esta
//  version actua como un "stub" que informa al usuario de que la
//  funcionalidad no esta disponible.
//
//  POR QUE CADA PLATAFORMA NECESITA SU PROPIA VERSION?
//  - Movil:     No puede usar dart:html (no existe en Android/iOS).
//               La generacion de PDF requeriria un plugin nativo o
//               una libreria diferente. Por ahora, solo lanza un error.
//  - Web:       Tiene acceso a dart:html para crear blobs y descargar
//               archivos directamente en el navegador. Ademas, usa el
//               paquete 'pdf' para generar el documento.
//  Este archivo existe para que la aplicacion compile correctamente
//  en todas las plataformas, aunque la funcionalidad no este completa.
// =============================================================================

/// Intenta generar y mostrar un PDF con una tabla de partes.
///
/// En la version movil (Android/iOS) esta funcionalidad NO esta
/// disponible. Si se llama, lanza un [UnimplementedError] indicando
/// que el PDF no se puede generar en esta plataforma.
///
/// Parametros:
///   [columnas]  - Lista de textos con los titulos de cada columna
///                 de la tabla (ej. ["Codigo", "Operario", ...]).
///   [filas]     - Lista de listas con los datos de cada fila.
///                 Cada elemento interno es una fila completa.
///   [subtotales]- Conjunto de indices de fila que representan
///                 subtotales (se renderizan con estilo diferente).
///   [titulo]    - Texto del titulo que aparece en el PDF.
///
/// Lanza:
///   [UnimplementedError] siempre, porque esta plataforma no soporta
///   la generacion de PDF.
Future<void> generarYMostrarPdf({
  required List<String> columnas,
  required List<List<String>> filas,
  required Set<int> subtotales,
  required String titulo,
}) async {
  // Lanza una excepcion informando que el PDF no esta disponible.
  // Esto evita que la aplicacion compile sin esta funcion y, si se
  // llama accidentalmente, da un mensaje claro en lugar de fallar
  // silenciosamente.
  throw UnimplementedError('PDF no disponible en esta plataforma.');
}

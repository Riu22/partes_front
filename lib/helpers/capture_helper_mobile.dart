/// Versión para móvil (Android / iOS) del helper de captura.
/// En móvil la generación de PDF todavía no está implementada.
/// Esta función existe solo para que la app compile en estas plataformas.
/// Si se llama, lanza un error diciendo que el PDF no está disponible.

/// Intenta generar un PDF con una tabla y mostrarlo al usuario.
/// En móvil esto NO funciona — solo está disponible en web.
///
/// - [columnas]: los títulos de cada columna de la tabla
/// - [filas]: los datos de cada fila
/// - [subtotales]: qué filas son subtotales (índices)
/// - [titulo]: el título que aparece en el PDF
Future<void> generarYMostrarPdf({
  required List<String> columnas,
  required List<List<String>> filas,
  required Set<int> subtotales,
  required String titulo,
}) async {
  throw UnimplementedError('PDF no disponible en esta plataforma.');
}

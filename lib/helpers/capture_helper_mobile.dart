// capture_helper_mobile.dart
// Stub para móvil (Android/iOS). La generación de PDF solo está implementada
// en web. En móvil esta función no hace nada, solo está para que la app compile.

Future<void> generarYMostrarPdf({
  required List<String> columnas,
  required List<List<String>> filas,
  required Set<int> subtotales,
  required String titulo,
}) async {
  throw UnimplementedError('PDF no disponible en esta plataforma.');
}

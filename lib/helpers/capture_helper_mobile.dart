// capture_helper_mobile.dart
// Stub para móvil (Android/iOS). La generación de PDF solo está implementada
// en web. En móvil esta función no hace nada para que la app compile.

Future<void> generarYMostrarPdf({
  required List<String> columnas,
  required List<List<String>> filas,
  required Set<int> subtotales,
  required String titulo,
}) async {
  // No implementado en móvil.
  // Si en el futuro quieres PDF en móvil, impleméntalo aquí con
  // el paquete `pdf` + `path_provider` + `open_file`.
  throw UnimplementedError('PDF no disponible en esta plataforma.');
}

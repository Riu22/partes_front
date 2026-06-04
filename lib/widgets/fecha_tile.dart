// =============================================================================
// fecha_tile.dart  -  Selector de rango de fechas
// =============================================================================
// ASPECTO EN PANTALLA:
//   Rectangulo con borde gris, icono de calendario azul, y dos fechas
//   separadas por una flecha "->" (ej: "01/01/2025 -> 15/01/2025").
//   Al tocarlo abre el DateRangePicker de Material Design.
//
// USO:
//   Seleccionar un rango de fechas para filtrar partes, exportar, o
//   visualizar informes.
//
// DATOS QUE NECESITA:
//   - desde: DateTime inicio del rango
//   - hasta: DateTime fin del rango
//   - onChanged: callback con el nuevo DateTimeRange seleccionado
//
// INTERACCION DEL USUARIO:
//   - Tocar el tile abre el selector de rango de fechas
//   - El selector permite elegir desde y hasta dentro de la app
//   - Al confirmar, ejecuta onChanged con el nuevo rango
// =============================================================================

/// Widget para seleccionar un rango de fechas (desde / hasta).
/// Al tocarlo abre un selector de fechas y notifica el nuevo rango.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tile que muestra un rango de fechas y abre un DateRangePicker al
/// tocarlo. [StatelessWidget] porque no tiene estado mutable.
class RangoFechaTile extends StatelessWidget {
  final DateTime desde;
  final DateTime hasta;
  final ValueChanged<DateTimeRange> onChanged;

  const RangoFechaTile({
    super.key,
    required this.desde,
    required this.hasta,
    required this.onChanged,
  });

  /// Abre el selector nativo de rango de fechas de Material Design.
  /// [firstDate] es 2020, [lastDate] es hoy.
  Future<void> _pickRango(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: desde, end: hasta),
    );
    if (picked == null) return;
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickRango(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            // Icono de calendario azul.
            const Icon(
              Icons.calendar_today,
              size: 16,
              color: Color(0xFF1565C0),
            ),
            const SizedBox(width: 10),
            // Fecha de inicio.
            Text(
              '${DateFormat('dd/MM/yyyy').format(desde)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            // Flecha separadora.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '\u2192',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Fecha de fin.
            Text(
              DateFormat('dd/MM/yyyy').format(hasta),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

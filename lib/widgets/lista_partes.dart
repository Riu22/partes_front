// =============================================================================
// lista_partes.dart  -  Lista completa de partes con scroll y agrupacion
// =============================================================================
// ASPECTO EN PANTALLA:
//   ListView vertical con padding inferior de 80px. Arriba (opcional)
//   un [ResumenSemanal]. Debajo, bloques de [DayHeader] por cada fecha,
//   ordenados de mas reciente a mas antigua. Si la lista esta vacia:
//   mensaje "No hay partes registrados" centrado.
//
// USO:
//   Pantalla principal de listado de partes. Agrupa por fecha y permite
//   mostrar resumen semanal y agrupacion por operario.
//
// DATOS QUE NECESITA:
//   - partes: List<ParteTrabajo> completa
//   - mostrarResumen: bool para mostrar/hide el resumen semanal
//   - agruparPorOperario: bool para agrupar dentro de cada dia
//
// INTERACCION DEL USUARIO:
//   - Scroll vertical para ver todos los dias
//   - Cada DayHeader se expande/colapsa independientemente
// =============================================================================

/// Lista completa de partes con scroll infinito.
/// Agrupa los partes por fecha (de más reciente a más antigua) y
/// opcionalmente muestra un resumen semanal y agrupación por operario.
import 'package:flutter/material.dart';
import '../helpers/fecha_helpers.dart';
import '../models/parte_trabajo.dart';
import 'resumen_semanal.dart';
import 'day_header.dart';

/// Lista principal de partes agrupados por fecha.
///
/// [StatelessWidget]: los datos vienen del padre; no hay estado local.
class ListaPartes extends StatelessWidget {
  final List<ParteTrabajo> partes;
  final bool mostrarResumen;
  final bool agruparPorOperario;

  const ListaPartes({
    super.key,
    required this.partes,
    this.mostrarResumen = false,
    this.agruparPorOperario = false,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay partes, muestra mensaje centrado.
    if (partes.isEmpty) {
      return const Center(
        child: Text(
          'No hay partes registrados',
          style: TextStyle(color: Color(0xFF888888)),
        ),
      );
    }

    // Agrupa partes por fecha (clave: string "yyyy-MM-dd").
    final Map<String, List<ParteTrabajo>> porFecha = {};
    for (final p in partes) {
      porFecha.putIfAbsent(fmtYMD(p.fecha), () => []).add(p);
    }

    // Ordena las fechas de mas reciente a mas antigua (descendente).
    final fechasOrdenadas = porFecha.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // Resumen semanal opcional (solo para operarios/encargados).
        if (mostrarResumen) ResumenSemanal(partes: partes),

        // Un DayHeader por cada fecha con sus partes.
        for (final fechaKey in fechasOrdenadas)
          DayHeader(
            fecha: DateTime.parse(fechaKey),
            partes: porFecha[fechaKey]!,
            agruparPorOperario: agruparPorOperario,
          ),
      ],
    );
  }
}

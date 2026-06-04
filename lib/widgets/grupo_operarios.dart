// =============================================================================
// grupo_operarios.dart  -  Agrupacion de partes por operario
// =============================================================================
// ASPECTO EN PANTALLA:
//   Columna vertical con una [FilaOperario] por cada operario distinto
//   que tenga partes en el dia. Cada fila muestra inicial, nombre, horas
//   y se expande para ver las tarjetas.
//
// USO:
//   Dentro de [DayHeader] cuando agruparPorOperario=true. Organiza los
//   partes de un dia agrupandolos por el nombre del operario.
//
// DATOS QUE NECESITA:
//   - partes: List<ParteTrabajo> de un mismo dia
//
// INTERACCION DEL USUARIO:
//   No tiene interaccion directa. Delega en FilaOperario.
// =============================================================================

/// Agrupa los partes por operario dentro de un mismo día.
/// Cada operario se muestra con su propia fila y total de horas.
import 'package:flutter/material.dart';
import '../models/parte_trabajo.dart';
import 'fila_operario.dart';

/// Agrupa partes por operario y renderiza una [FilaOperario] por cada uno.
///
/// [StatelessWidget]: no tiene estado, solo transforma datos.
class GrupoOperarios extends StatelessWidget {
  final List<ParteTrabajo> partes;

  const GrupoOperarios({super.key, required this.partes});

  @override
  Widget build(BuildContext context) {
    // Construye un mapa: nombre_operario -> lista de partes.
    final Map<String, List<ParteTrabajo>> porOperario = {};
    for (final p in partes) {
      porOperario.putIfAbsent(p.operarioNombreCompleto, () => []).add(p);
    }

    // Obtiene los nombres de operario ordenados alfabeticamente.
    final operarios = porOperario.keys.toList()..sort();

    return Column(
      // Renderiza una FilaOperario por cada operario.
      children: operarios
          .map(
            (nombre) =>
                FilaOperario(nombre: nombre, partes: porOperario[nombre]!),
          )
          .toList(),
    );
  }
}

/// Agrupa los partes por operario dentro de un mismo día.
/// Cada operario se muestra con su propia fila y total de horas.
import 'package:flutter/material.dart';
import '../models/parte_trabajo.dart';
import 'fila_operario.dart';

class GrupoOperarios extends StatelessWidget {
  final List<ParteTrabajo> partes;

  const GrupoOperarios({super.key, required this.partes});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<ParteTrabajo>> porOperario = {};
    for (final p in partes) {
      porOperario.putIfAbsent(p.operarioNombreCompleto, () => []).add(p);
    }
    final operarios = porOperario.keys.toList()..sort();

    return Column(
      children: operarios
          .map(
            (nombre) =>
                FilaOperario(nombre: nombre, partes: porOperario[nombre]!),
          )
          .toList(),
    );
  }
}

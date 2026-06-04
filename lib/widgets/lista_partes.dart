/// Lista completa de partes con scroll infinito.
/// Agrupa los partes por fecha (de más reciente a más antigua) y
/// opcionalmente muestra un resumen semanal y agrupación por operario.
import 'package:flutter/material.dart';
import '../helpers/fecha_helpers.dart';
import '../models/parte_trabajo.dart';
import 'resumen_semanal.dart';
import 'day_header.dart';

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
    if (partes.isEmpty) {
      return const Center(
        child: Text(
          'No hay partes registrados',
          style: TextStyle(color: Color(0xFF888888)),
        ),
      );
    }

    final Map<String, List<ParteTrabajo>> porFecha = {};
    for (final p in partes) {
      porFecha.putIfAbsent(fmtYMD(p.fecha), () => []).add(p);
    }
    final fechasOrdenadas = porFecha.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (mostrarResumen) ResumenSemanal(partes: partes),
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

import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';
import '../models/parte_trabajo.dart';
import 'stat_box.dart';

class ResumenSemanal extends StatelessWidget {
  final List<ParteTrabajo> partes;

  const ResumenSemanal({super.key, required this.partes});

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
    final finSemana = inicioSemana.add(const Duration(days: 6));

    final partesSemana = partes.where((p) {
      return !p.fecha.isBefore(
            DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day),
          ) &&
          !p.fecha.isAfter(
            DateTime(finSemana.year, finSemana.month, finSemana.day, 23, 59),
          );
    }).toList();

    final totalSemana = partesSemana.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );
    final partesHoy = partes.where(
      (p) =>
          p.fecha.year == ahora.year &&
          p.fecha.month == ahora.month &&
          p.fecha.day == ahora.day,
    );
    final horasHoy = partesHoy.fold<double>(0, (s, p) => s + p.horasNormales);
    final progreso = (totalSemana / 40).clamp(0.0, 1.0);
    final hayExtra = horasHoy > 8;

    String fmt(double h) =>
        h == h.truncateToDouble() ? '${h.toInt()}' : h.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ESTA SEMANA',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.5,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatBox(
                  label: 'Total',
                  value: '${fmt(totalSemana)}h',
                  valueColor: blue,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: StatBox(
                  label: 'Partes',
                  value: '${partesSemana.length}',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: StatBox(
                  label: 'Hoy',
                  value: '${fmt(horasHoy)}h',
                  valueColor: hayExtra ? orange : textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 3,
              backgroundColor: bgStat,
              valueColor: AlwaysStoppedAnimation(
                totalSemana > 40 ? orange : blue,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '0h',
                style: TextStyle(fontSize: 10, color: textSecondary),
              ),
              if (hayExtra)
                Text(
                  'Hoy: ${fmt(horasHoy)}h · jornada 8h',
                  style: const TextStyle(
                    fontSize: 10,
                    color: orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const Text(
                '40h',
                style: TextStyle(fontSize: 10, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// resumen_semanal.dart  -  Resumen semanal de horas trabajadas
// =============================================================================
// ASPECTO EN PANTALLA:
//   Recuadro blanco con borde gris. Arriba texto "ESTA SEMANA" en gris.
//   Tres cajitas (StatBox) en fila: "Total" (horas totales en azul),
//   "Partes" (cantidad), "Hoy" (horas de hoy, naranja si son extras).
//   Debajo: barra de progreso horizontal (azul normalmente, naranja si
//   supera 40h). Y etiquetas "0h" a izquierda, "40h" a derecha, y alerta
//   "Hoy: Xh - jornada 8h" si horasHoy > 8.
//
// USO:
//   Dar al operario una vision rapida de su jornada semanal y diaria.
//   Se muestra al inicio de la lista de partes para operarios/encargados.
//
// DATOS QUE NECESITA:
//   - partes: List<ParteTrabajo> completa (filtra internamente la semana)
//
// INTERACCION DEL USUARIO:
//   Solo informativo, no interactivo.
// =============================================================================

/// Resumen semanal de horas trabajadas.
/// Muestra total de horas de la semana, cantidad de partes, horas de hoy,
/// una barra de progreso sobre 40h y alerta si hay horas extra.
import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';
import '../models/parte_trabajo.dart';
import 'stat_box.dart';

/// Panel de resumen semanal con estadisticas y barra de progreso.
///
/// [StatelessWidget]: calcula todo en base a las partes recibidas.
class ResumenSemanal extends StatelessWidget {
  final List<ParteTrabajo> partes;

  const ResumenSemanal({super.key, required this.partes});

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();

    // Calcula el inicio de la semana actual (lunes).
    final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
    // Calcula el fin de la semana (domingo).
    final finSemana = inicioSemana.add(const Duration(days: 6));

    // Filtra partes que caen dentro de la semana actual (lunes a domingo).
    final partesSemana = partes.where((p) {
      return !p.fecha.isBefore(
            DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day),
          ) &&
          !p.fecha.isAfter(
            DateTime(finSemana.year, finSemana.month, finSemana.day, 23, 59),
          );
    }).toList();

    // Suma total de horas de la semana.
    final totalSemana = partesSemana.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );

    // Filtra partes de hoy.
    final partesHoy = partes.where(
      (p) =>
          p.fecha.year == ahora.year &&
          p.fecha.month == ahora.month &&
          p.fecha.day == ahora.day,
    );
    final horasHoy = partesHoy.fold<double>(0, (s, p) => s + p.horasNormales);

    // Progreso sobre 40h (jornada semanal estandar).
    final progreso = (totalSemana / 40).clamp(0.0, 1.0);
    // Alerta si hoy se superan las 8h.
    final hayExtra = horasHoy > 8;

    // Formatea horas: sin decimales si es entero.
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
          // ── TITULO ─────────────────────────────────────────
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

          // ── TRES CAJAS DE ESTADISTICA ──────────────────────
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

          // ── BARRA DE PROGRESO ─────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 3,
              backgroundColor: bgStat,
              // Color de la barra: naranja si supera 40h, azul si no.
              valueColor: AlwaysStoppedAnimation(
                totalSemana > 40 ? orange : blue,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── ETIQUETAS DE LA BARRA ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '0h',
                style: TextStyle(fontSize: 10, color: textSecondary),
              ),
              // Alerta de horas extra si corresponde.
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

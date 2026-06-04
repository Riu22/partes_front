// =============================================================================
// day_header.dart  -  Encabezado de dia en calendario de partes
// =============================================================================
// ASPECTO EN PANTALLA:
//   Fila horizontal con: icono de flecha (expandir/colapsar), label del dia
//   (ej: "Jue 15 ene" o "Hoy 15 ene"), pastilla azul con total de horas,
//   y a la derecha texto con "N parte(s)" o "N persona(s)".
//   Al expandir muestra los partes del dia, bien como lista simple
//   ([ListaCards]) o agrupados por operario ([GrupoOperarios]).
//
// USO:
//   Organizar los partes agrupados por fecha, de mas reciente a mas antigua.
//   Es el elemento principal de la lista de partes ([ListaPartes]).
//
// DATOS QUE NECESITA:
//   - fecha: DateTime del dia
//   - partes: List<ParteTrabajo> de ese dia
//   - agruparPorOperario: bool que cambia la vista expandida
//
// INTERACCION DEL USUARIO:
//   - Tocar la cabecera expande/colapsa el contenido del dia
//   - Al expandir, si agruparPorOperario=true agrupa por operario,
//     si no, muestra lista plana de tarjetas
// =============================================================================

/// Encabezado de un día en el calendario de partes.
/// Muestra la fecha, total de horas, cantidad de partes y permite
/// expandir para ver los partes o agruparlos por operario.
import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';
import '../models/parte_trabajo.dart';
import 'grupo_operarios.dart';
import 'lista_cards.dart';

/// Encabezado expandible de un dia en el listado de partes.
///
/// [StatefulWidget] porque mantiene el estado _expandido para saber
/// si debe mostrar u ocultar los partes de ese dia.
class DayHeader extends StatefulWidget {
  final DateTime fecha;
  final List<ParteTrabajo> partes;
  final bool agruparPorOperario;

  const DayHeader({
    super.key,
    required this.fecha,
    required this.partes,
    required this.agruparPorOperario,
  });

  @override
  State<DayHeader> createState() => _DayHeaderState();
}

class _DayHeaderState extends State<DayHeader> {
  // Controla si el contenido del dia esta visible o colapsado.
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();

    // Determina si esta cabecera corresponde al dia de hoy.
    final esHoy =
        widget.fecha.year == hoy.year &&
        widget.fecha.month == hoy.month &&
        widget.fecha.day == hoy.day;

    // Calcula el total de horas sumando horasNormales de todos los partes.
    final totalHoras = widget.partes.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );

    // Arreglos para nombres de meses y dias en espanol.
    final meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final dias = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

    // Label del dia: "Hoy 15 ene" si es hoy, "Jue 15 ene" si no.
    final diaLabel = esHoy
        ? 'Hoy ${widget.fecha.day} ${meses[widget.fecha.month - 1]}'
        : '${dias[widget.fecha.weekday - 1]} ${widget.fecha.day} ${meses[widget.fecha.month - 1]}';

    final h = totalHoras;
    // Si el total de horas es un numero entero, muestra sin decimales (ej: "8h").
    // Si tiene decimales, muestra uno (ej: "7.5h").
    final horasLabel = h == h.truncateToDouble()
        ? '${h.toInt()}h'
        : '${h.toStringAsFixed(1)}h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CABECERA DEL DIA (tocable) ───────────────────────
        GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                // Flecha indicadora: abajo si expandido, derecha si colapsado.
                Icon(
                  _expandido
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: textSecondary,
                ),
                const SizedBox(width: 4),
                // Nombre del dia: azul si es hoy, gris oscuro si no.
                Text(
                  diaLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: esHoy ? blue : textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                // Pastilla azul con el total de horas del dia.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: bluePill,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    horasLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: blue,
                    ),
                  ),
                ),
                const Spacer(),
                // Texto informativo: cantidad de personas o partes.
                Text(
                  widget.agruparPorOperario
                      ? '${_operariosUnicos(widget.partes)} persona(s)'
                      : '${widget.partes.length} parte(s)',
                  style: const TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
        ),
        // ── CONTENIDO EXPANDIDO ─────────────────────────────
        // Solo se renderiza cuando _expandido es true.
        if (_expandido)
          widget.agruparPorOperario
              ? GrupoOperarios(partes: widget.partes)
              : ListaCards(partes: widget.partes),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Cuenta cuantos operarios distintos hay en la lista de partes,
  /// basandose en el nombre completo del operario.
  int _operariosUnicos(List<ParteTrabajo> partes) =>
      partes.map((p) => p.operarioNombreCompleto).toSet().length;
}

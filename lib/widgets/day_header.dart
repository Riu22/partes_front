import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';
import '../models/parte_trabajo.dart';
import 'grupo_operarios.dart';
import 'lista_cards.dart';

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
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final esHoy =
        widget.fecha.year == hoy.year &&
        widget.fecha.month == hoy.month &&
        widget.fecha.day == hoy.day;

    final totalHoras = widget.partes.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );

    final meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sab', 'Dom'];
    final diaLabel = esHoy
        ? 'Hoy ${widget.fecha.day} ${meses[widget.fecha.month - 1]}'
        : '${dias[widget.fecha.weekday - 1]} ${widget.fecha.day} ${meses[widget.fecha.month - 1]}';

    final h = totalHoras;
    // Si el total de horas es un número entero, muestra sin decimales (ej: "8h")
    final horasLabel = h == h.truncateToDouble()
        ? '${h.toInt()}h'
        : '${h.toStringAsFixed(1)}h';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                Icon(
                  _expandido
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  diaLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: esHoy ? blue : textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
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
        if (_expandido)
          widget.agruparPorOperario
              ? GrupoOperarios(partes: widget.partes)
              : ListaCards(partes: widget.partes),
        const SizedBox(height: 4),
      ],
    );
  }

  int _operariosUnicos(List<ParteTrabajo> partes) =>
      partes.map((p) => p.operarioNombreCompleto).toSet().length;
}

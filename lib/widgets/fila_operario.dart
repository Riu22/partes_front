import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';
import '../models/parte_trabajo.dart';
import 'card_parte.dart';

class FilaOperario extends StatefulWidget {
  final String nombre;
  final List<ParteTrabajo> partes;

  const FilaOperario({
    super.key,
    required this.nombre,
    required this.partes,
  });

  @override
  State<FilaOperario> createState() => _FilaOperarioState();
}

class _FilaOperarioState extends State<FilaOperario> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final totalHoras = widget.partes.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );
    // Lógica de colores: verde si son 8h exactas, rojo si <8h, naranja si >8h (extras)
    final horas8 = (totalHoras - 8).abs() < 0.01;
    final horasBajas = totalHoras < 8;

    Color pillColor;
    Color textColor;
    if (horas8) {
      pillColor = greenPill;
      textColor = greenOk;
    } else if (horasBajas) {
      pillColor = redPill;
      textColor = redAlert;
    } else {
      pillColor = orangePill;
      textColor = orange;
    }

    final horasLabel = totalHoras == totalHoras.truncateToDouble()
        ? '${totalHoras.toInt()}h'
        : '${totalHoras.toStringAsFixed(1)}h';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: bgStat,
                    child: Text(
                      widget.nombre.isNotEmpty
                          ? widget.nombre[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.nombre,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  if (widget.partes.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${widget.partes.length} partes',
                        style: const TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      horasLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expandido)
            ...widget.partes.map(
              (p) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: CardParte(parte: p),
              ),
            ),
        ],
      ),
    );
  }
}

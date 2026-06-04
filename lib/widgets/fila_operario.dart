// =============================================================================
// fila_operario.dart  -  Fila de operario en agrupacion por persona
// =============================================================================
// ASPECTO EN PANTALLA:
//   Rectangulo con borde gris, avatar circular con la inicial del nombre,
//   nombre del operario, contador de partes (si tiene mas de 1), pastilla
//   con total de horas (verde si son 8h exactas, rojo si <8h, naranja si
//   >8h), y flecha de expandir. Al expandir se muestran las tarjetas
//   [CardParte] de cada parte del operario.
//
// USO:
//   Agrupar los partes de un dia por operario, mostrando el total de horas
//   de cada uno con indicador visual de cumplimiento de jornada.
//
// DATOS QUE NECESITA:
//   - nombre: String del operario
//   - partes: List<ParteTrabajo> de ese operario en el dia
//
// INTERACCION DEL USUARIO:
//   - Tocar la fila expande/colapsa los partes individuales
//   - Cada parte expandido muestra la tarjeta CardParte completa
// =============================================================================

/// Fila que representa a un operario dentro de un grupo.
/// Muestra su nombre, total de horas (con color según cumpla la jornada)
/// y la cantidad de partes. Al expandir se ven las tarjetas de cada parte.
import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';
import '../models/parte_trabajo.dart';
import 'card_parte.dart';

/// Fila expandible de un operario con su total de horas y lista de partes.
///
/// [StatefulWidget] porque mantiene _expandido para mostrar/ocultar
/// los partes individuales.
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
    // Suma todas las horas normales de los partes de este operario.
    final totalHoras = widget.partes.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );

    // Logica de colores:
    // - Verde si son 8h exactas (jornada completa)
    // - Rojo si <8h (jornada incompleta)
    // - Naranja si >8h (horas extra)
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

    // Formatea las horas: sin decimales si es entero, con 1 decimal si no.
    final horasLabel = totalHoras == totalHoras.truncateToDouble()
        ? '${totalHoras.toInt()}h'
        : '${totalHoras.toStringAsFixed(1)}h';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          // ── FILA DEL OPERARIO (tocable) ─────────────────────
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
                  // Avatar circular con la inicial del nombre.
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
                  // Nombre del operario.
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
                  // Contador de partes (solo si tiene mas de 1).
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
                  // Pastilla de horas con color segun jornada.
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
                  // Flecha indicadora de expansion.
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
          // ── PARTES EXPANDIDOS ────────────────────────────
          if (_expandido)
            // Itera sobre los partes y muestra cada uno como CardParte.
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

import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';
import '../helpers/fecha_helpers.dart';

class CardParteJefe extends StatelessWidget {
  final dynamic parte;

  const CardParteJefe({super.key, required this.parte});

  @override
  Widget build(BuildContext context) {
    final fechaStr = parte['fecha'] ?? '';
    final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();
    final obras = (parte['obras'] as List?) ?? [];
    final hoy = DateTime.now();
    final puedeEditar =
        fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
    final descripcion =
        (parte['descripcion'] != null &&
            parte['descripcion'].toString().isNotEmpty)
        ? parte['descripcion']
        : 'Sin descripción';

    return Card(
      color: bgCard,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: cardBorder),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: puedeEditar ? orangePill : bgStat,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.assignment_outlined,
            size: 18,
            color: puedeEditar ? orange : textSecondary,
          ),
        ),
        title: Text(
          fmtDMY(fecha),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        subtitle: Text(
          '${obras.length} obra(s)',
          style: const TextStyle(fontSize: 12, color: textSecondary),
        ),
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: cardBorder)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribución',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...obras.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.business_outlined,
                          size: 14,
                          color: blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            o['obra']?['nombre'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${o['porcentaje']}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: cardBorder),
                const Text(
                  'Descripción',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta que muestra un parte de trabajo para el jefe de obra.
/// Muestra la fecha, las obras asociadas con sus porcentajes (eléctrico/mecánico),
/// la descripción y botones para editar o eliminar.
import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';
import '../helpers/fecha_helpers.dart';

class CardParteJefe extends StatelessWidget {
  final dynamic parte;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  const CardParteJefe({
    super.key,
    required this.parte,
    this.onEditar,
    this.onEliminar,
  });

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
      clipBehavior: Clip.none,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: cardBorder),
      ),
      child: ExpansionTile(
        clipBehavior: Clip.none,
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
                if (obras.isNotEmpty) ...[
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
                      padding: const EdgeInsets.only(bottom: 6),
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
                            '⚡${(o['porcentaje_electrico'] as num?)?.toStringAsFixed(0) ?? '0'}%'
                            ' · '
                            '🔧${(o['porcentaje_mecanico'] as num?)?.toStringAsFixed(0) ?? '0'}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: cardBorder),
                ],
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
                // ─── BOTONES EDITAR / ELIMINAR ───────────────
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: puedeEditar ? onEditar : null,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                      style: TextButton.styleFrom(
                        foregroundColor: orange,
                        disabledForegroundColor: textSecondary,
                        textStyle: const TextStyle(fontSize: 13),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onEliminar,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Eliminar'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        textStyle: const TextStyle(fontSize: 13),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

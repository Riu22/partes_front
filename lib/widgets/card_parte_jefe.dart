// =============================================================================
// card_parte_jefe.dart  -  Tarjeta de parte para jefe de obra
// =============================================================================
// ASPECTO EN PANTALLA:
//   Tarjeta blanca con borde gris claro. A la izquierda un icono cuadrado
//   naranja (si se puede editar) o gris. Titulo con la fecha y subtitulo
//   con "N obra(s)". Al expandir (ExpansionTile) se ve:
//     - Distribucion: lista de obras con icono, nombre y porcentajes
//       electrico/mecanico
//     - Descripcion del parte
//     - Botones "Editar" (naranja, solo si es hoy) y "Eliminar" (rojo)
//
// USO:
//   Mostrar partes creados por el jefe de obra, donde asigna porcentajes
//   de dedicacion a cada obra (electrico/mecanico).
//
// DATOS QUE NECESITA:
//   - parte: Map con claves fecha, obras (lista con obra[nombre] y
//     porcentaje_electrico/mecanico), descripcion, id
//   - onEditar: callback opcional para editar
//   - onEliminar: callback opcional para eliminar
//
// INTERACCION DEL USUARIO:
//   - Tocar la cabecera expande/colapsa los detalles
//   - Tocar "Editar" (solo disponible si la fecha es hoy) abre el editor
//   - Tocar "Eliminar" pide confirmacion y borra el parte
// =============================================================================

/// Tarjeta que muestra un parte de trabajo para el jefe de obra.
/// Muestra la fecha, las obras asociadas con sus porcentajes (eléctrico/mecánico),
/// la descripción y botones para editar o eliminar.
import 'package:flutter/material.dart';
import '../helpers/tema_constants.dart';
import '../helpers/fecha_helpers.dart';

/// Tarjeta expandible para partes del jefe de obra con distribucion
/// de porcentajes por obra (electrico/mecanico).
///
/// [StatelessWidget] porque no mantiene estado; ExpansionTile maneja
/// su propia expansion internamente.
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
    // Parsea la fecha del parte desde un string ISO.
    final fechaStr = parte['fecha'] ?? '';
    final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();

    // Lista de obras asociadas al parte (cada una con nombre y porcentajes).
    final obras = (parte['obras'] as List?) ?? [];

    final hoy = DateTime.now();

    // Solo se puede editar si el parte es del dia actual.
    final puedeEditar =
        fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;

    // Si no hay descripcion, muestra un placeholder.
    final descripcion =
        (parte['descripcion'] != null &&
            parte['descripcion'].toString().isNotEmpty)
        ? parte['descripcion']
        : 'Sin descripción';

    return Card(
      color: bgCard,
      elevation: 0, // Sin sombra, solo borde.
      clipBehavior: Clip.none,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: cardBorder),
      ),
      child: ExpansionTile(
        // [ExpansionTile] es un ListTile que se expande al tocarlo.
        // Muestra los children debajo cuando esta abierto.
        clipBehavior: Clip.none,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        // Icono cuadrado indicador: naranja si editable, gris si no.
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
          // Fecha formateada con fmtDMY (ej: "15/03/2025").
          fmtDMY(fecha),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        // Subtitulo: cantidad de obras.
        subtitle: Text(
          '${obras.length} obra(s)',
          style: const TextStyle(fontSize: 12, color: textSecondary),
        ),
        children: [
          // ── CONTENIDO EXPANDIDO ────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: cardBorder)),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── LISTA DE OBRAS CON PORCENTAJES ─────────────
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
                  // Itera sobre cada obra mostrando nombre y % electrico/mecanico.
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
                          // Muestra porcentaje electrico y mecanico.
                          // NOTA: contiene caracteres unicode (rayo, llave)
                          // que podrian verse como emojis en algunos sistemas.
                          Text(
                            '\u26A1${(o['porcentaje_electrico'] as num?)?.toStringAsFixed(0) ?? '0'}%'
                            ' \u00B7 '
                            '\uD83D\uDD27${(o['porcentaje_mecanico'] as num?)?.toStringAsFixed(0) ?? '0'}%',
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

                // ── DESCRIPCION ──────────────────────────────
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
                    // Boton Editar: solo activo si puedeEditar (fecha = hoy).
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
                    // Boton Eliminar: siempre activo, color rojo.
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

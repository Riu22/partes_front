/// Tarjeta que muestra un parte de trabajo para el operario.
/// Incluye obra, fecha, horas, especialidad, descripción, firma del cliente
/// y botones para editar o eliminar (si tiene permisos).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../helpers/tema_constants.dart';
import '../helpers/fecha_helpers.dart';
import '../models/parte_trabajo.dart';
import '../providers/auth_provider.dart';
import '../providers/partes_provider.dart';
import 'chip_especialidad.dart';

class CardParte extends ConsumerWidget {
  final ParteTrabajo parte;

  const CardParte({super.key, required this.parte});

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar parte'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este parte? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: redAlert),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await ref.read(apiServiceProvider).eliminarParte(parte.id);
      ref.invalidate(partesProvider);
      ref.invalidate(partesJefeProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parte eliminado correctamente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;
    final esGestor = perfil?.esAdmin == true || perfil?.esGestion == true;

    final fechasPermitidas = esGestor
        ? <DateTime>[]
        : ref.watch(fechasPermitidasProvider).valueOrNull ?? [];

    // Los gestores siempre pueden editar; los operarios solo si es hoy o hay fecha habilitada
    final puedeEditar =
        esGestor || parte.puedeEditarseConFechas(fechasPermitidas);
    final puedeEliminar =
        esGestor || parte.puedeEditarseConFechas(fechasPermitidas);

    final String? esp = parte.especialidad;
    final bool esElec = esp == 'ELECTRICIDAD'; // Determina color del chip de especialidad

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
        childrenPadding: EdgeInsets.zero,
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
          parte.obraNombre,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        subtitle: Row(
          children: [
            if (parte.creadoPorGestor)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ADMIN',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
              ),
            Text(
              fmtDMY(parte.fecha),
              style: const TextStyle(fontSize: 12, color: textSecondary),
            ),
            if ((parte.firmaUrl != null && parte.firmaUrl!.isNotEmpty) ||
                (parte.nombreFirma != null && parte.nombreFirma!.isNotEmpty)) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: greenPill,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.draw_outlined, size: 9, color: greenOk),
                    const SizedBox(width: 3),
                    Text(
                      parte.nombreFirma != null && parte.nombreFirma!.isNotEmpty
                          ? parte.nombreFirma!
                          : 'FIRMADO',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: greenOk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${parte.horasNormales % 1 == 0 ? parte.horasNormales.toInt() : parte.horasNormales}h',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: textPrimary,
                height: 1,
              ),
            ),
            if (esp != null) ...[
              const SizedBox(height: 4),
              ChipEspecialidad(especialidad: esp, esElec: esElec),
            ],
          ],
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
                // ── Descripción ──
                const Text(
                  'Descripción',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  parte.descripcion.isNotEmpty
                      ? parte.descripcion
                      : 'Sin descripción',
                  style: const TextStyle(
                    fontSize: 13,
                    color: textPrimary,
                    height: 1.5,
                  ),
                ),

                // ── Firma ──
                if ((parte.firmaUrl != null && parte.firmaUrl!.isNotEmpty) ||
                    (parte.nombreFirma != null && parte.nombreFirma!.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Firma del cliente',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                      if (parte.nombreFirma != null &&
                          parte.nombreFirma!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: greenPill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 11,
                                color: greenOk,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                parte.nombreFirma!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: greenOk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      parte.firmaUrl!,
                      height: 120,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: bgStat,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: blue,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 48,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: redPill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 16,
                              color: redAlert,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'No se pudo cargar la firma',
                              style: TextStyle(fontSize: 12, color: redAlert),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Botones editar / eliminar ──
                if (puedeEditar || puedeEliminar) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (puedeEditar)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: const BorderSide(color: cardBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () =>
                                context.go('/partes/editar', extra: parte),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text(
                              'Editar',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      if (puedeEditar && puedeEliminar)
                        const SizedBox(width: 8),
                      if (puedeEliminar)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: redAlert,
                              side: const BorderSide(color: redAlert),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _eliminar(context, ref),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text(
                              'Eliminar',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

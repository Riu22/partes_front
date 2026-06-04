// =============================================================================
// partes_views.dart  -  Pantallas de vistas de partes
// =============================================================================
// ASPECTO EN PANTALLA:
//   Contiene tres vistas:
//
//   1. PartesNormalesView: Lista de partes de operarios, con resumen
//      semanal opcional, agrupados por fecha (usando ListaPartes).
//   2. PartesJefeView: Lista de partes del jefe de obra (tarjetas
//      CardParteJefe con porcentajes), con botones editar/eliminar.
//   3. PartesJefeCombinadaView: Vista combinada que muestra primero
//      "Mis partes por porcentaje" (jefe) y luego separa por
//      especialidad "Electricidad" y "Fontaneria", cada una agrupada
//      por obra o por fecha segun el rol.
//
// USO:
//   Renderizado condicional segun el rol del usuario. Se usa en la
//   pantalla de partes con tabs o selector de modo.
//
// DATOS QUE NECESITA:
//   - partesProvider: lista de partes de operarios
//   - partesJefeProvider: lista de partes del jefe de obra
//   - authProvider: para permisos y roles
//
// INTERACCION DEL USUARIO:
//   - Expandir/colapsar secciones y tarjetas
//   - Editar/Eliminar partes (solo si tiene permisos)
//   - Navegar a pantallas de edicion
// =============================================================================

/// Pantallas combinadas de partes: vista normal para operarios,
/// vista para jefe de obra y vista combinada que muestra ambas
/// (partes por porcentaje del jefe + partes por especialidad).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../helpers/tema_constants.dart';
import '../helpers/fecha_helpers.dart';
import '../models/parte_trabajo.dart';
import '../providers/partes_provider.dart';
import '../providers/auth_provider.dart';
import 'lista_partes.dart';
import 'card_parte_jefe.dart';
import 'day_header.dart';

// ── HELPER COMPARTIDO ────────────────────────────────────────────────────────

/// Muestra dialogo de confirmacion y elimina un parte de jefe de obra.
///
/// Usa [showDialog] para confirmar, luego llama al API via
/// [apiServiceProvider] e invalida [partesJefeProvider].
Future<void> _confirmarEliminar(
  BuildContext context,
  WidgetRef ref,
  dynamic parteId,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: bgCard,
      title: const Text(
        'Eliminar parte',
        style: TextStyle(color: textPrimary, fontSize: 16),
      ),
      content: const Text(
        '¿Seguro que quieres eliminar este parte?',
        style: TextStyle(color: textSecondary, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar', style: TextStyle(color: textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Eliminar',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    ),
  );

  if (confirm == true && context.mounted) {
    try {
      await ref.read(apiServiceProvider).deleteParteJefe(parteId);
      ref.invalidate(partesJefeProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Parte eliminado')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }
}

// ── VISTAS ───────────────────────────────────────────────────────────────────

/// Vista de partes normales (operarios). Muestra [ListaPartes] con datos
/// de [partesProvider]. Opcionalmente agrupa por operario.
///
/// [ConsumerWidget] para acceder a providers de Riverpod.
/// ref.watch() escucha cambios; el widget se reconstruye al cambiar.
class PartesNormalesView extends ConsumerWidget {
  final bool agruparPorOperario;

  const PartesNormalesView({super.key, required this.agruparPorOperario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escucha el provider de partes. Se reconstruye al cambiar.
    final partesAsync = ref.watch(partesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;

    // El resumen semanal solo se muestra para operarios y encargados.
    final mostrarResumen =
        perfil?.esOperario == true || perfil?.esEncargado == true;

    // [.when] maneja los tres estados de AsyncValue: loading, error, data.
    return partesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: blue)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: textSecondary)),
      ),
      data: (partes) => ListaPartes(
        partes: partes,
        mostrarResumen: mostrarResumen,
        agruparPorOperario: agruparPorOperario,
      ),
    );
  }
}

/// Vista de partes del jefe de obra. Muestra lista de [CardParteJefe]
/// con botones editar/eliminar. Datos de [partesJefeProvider].
class PartesJefeView extends ConsumerWidget {
  const PartesJefeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesJefeProvider);
    return partesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: blue)),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: textSecondary)),
      ),
      data: (partes) {
        if (partes.isEmpty) {
          return const Center(
            child: Text(
              'No hay partes registrados',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          );
        }
        // ListView con cada parte como CardParteJefe.
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
          itemCount: partes.length,
          itemBuilder: (context, index) {
            final p = partes[index];
            return CardParteJefe(
              parte: p,
              // Navega a edicion con los datos del parte como Map.
              onEditar: () => context.push(
                '/partes/editar-jefe/${p['id']}',
                extra: Map<String, dynamic>.from(p as Map),
              ),
              onEliminar: () => _confirmarEliminar(context, ref, p['id']),
            );
          },
        );
      },
    );
  }
}

/// Vista combinada: partes del jefe (porcentajes) + partes separados
/// por especialidad (Electricidad / Fontaneria). Cada especialidad se
/// agrupa por obra o por fecha segun el rol.
class PartesJefeCombinadaView extends ConsumerWidget {
  const PartesJefeCombinadaView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesNormalesAsync = ref.watch(partesProvider);
    final partesJefeAsync = ref.watch(partesJefeProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final esJefeObra = perfil?.esJefeObra == true;

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // ── PARTES DEL JEFE (siempre visibles, primero) ──
        partesJefeAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: blue)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error: $e',
              style: const TextStyle(color: textSecondary),
            ),
          ),
          data: (partes) {
            if (partes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Text(
                  'No hay partes registrados',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Text(
                    'Mis partes por porcentaje',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                // Renderiza cada parte del jefe como CardParteJefe.
                ...partes.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CardParteJefe(
                      parte: p,
                      onEditar: () => context.push(
                        '/partes/editar-jefe/${p['id']}',
                        extra: Map<String, dynamic>.from(p as Map),
                      ),
                      onEliminar: () =>
                          _confirmarEliminar(context, ref, p['id']),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 4),
        const Divider(color: cardBorder, height: 1),
        const SizedBox(height: 4),

        // ── PARTES POR ESPECIALIDAD ──────────────────────────
        partesNormalesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: blue)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error: $e',
              style: const TextStyle(color: textSecondary),
            ),
          ),
          data: (partes) {
            // Separa partes por especialidad.
            final electricos = partes
                .where((p) => p.especialidad == 'ELECTRICIDAD')
                .toList();
            final fontaneria = partes
                .where((p) => p.especialidad == 'FONTANERIA')
                .toList();

            return Column(
              children: [
                _SeccionEspecialidad(
                  titulo: 'Electricidad',
                  icono: Icons.bolt_outlined,
                  partes: electricos,
                  agruparPorObra: esJefeObra,
                ),
                const SizedBox(height: 4),
                _SeccionEspecialidad(
                  titulo: 'Fontanería',
                  icono: Icons.water_drop_outlined,
                  partes: fontaneria,
                  agruparPorObra: esJefeObra,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── SECCION DESPLEGABLE POR ESPECIALIDAD ────────────────────────────────────

/// Seccion expandible para una especialidad (Electricidad/Fontaneria).
/// Muestra icono, nombre, total de horas, cantidad de personas.
/// Al expandir, si agruparPorObra=true agrupa por obra, si no, por fecha.
class _SeccionEspecialidad extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final List<ParteTrabajo> partes;
  final bool agruparPorObra;

  const _SeccionEspecialidad({
    required this.titulo,
    required this.icono,
    required this.partes,
    this.agruparPorObra = false,
  });

  @override
  State<_SeccionEspecialidad> createState() => _SeccionEspecialidadState();
}

class _SeccionEspecialidadState extends State<_SeccionEspecialidad> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    // Calcula total de horas de todos los partes de esta especialidad.
    final totalHoras = widget.partes.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );
    final horasLabel = totalHoras == totalHoras.truncateToDouble()
        ? '${totalHoras.toInt()}h'
        : '${totalHoras.toStringAsFixed(1)}h';

    // Cuenta operarios unicos en esta especialidad.
    final operariosUnicos = widget.partes
        .map((p) => p.operarioNombreCompleto)
        .toSet()
        .length;

    Widget contenido;

    if (widget.agruparPorObra) {
      // Agrupacion por obra: obra -> dia -> operarios.
      final Map<String, List<ParteTrabajo>> porObra = {};
      for (final p in widget.partes) {
        porObra.putIfAbsent(p.obraNombre, () => []).add(p);
      }
      final obrasOrdenadas = porObra.keys.toList()..sort();

      contenido = Column(
        children: obrasOrdenadas
            .map((obra) => _ObraGroup(obraNombre: obra, partes: porObra[obra]!))
            .toList(),
      );
    } else {
      // Agrupacion por fecha (default).
      final Map<String, List<ParteTrabajo>> porFecha = {};
      for (final p in widget.partes) {
        porFecha.putIfAbsent(fmtYMD(p.fecha), () => []).add(p);
      }
      final fechasOrdenadas = porFecha.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      contenido = Column(
        children: [
          for (final fechaKey in fechasOrdenadas)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: DayHeader(
                fecha: DateTime.parse(fechaKey),
                partes: porFecha[fechaKey]!,
                agruparPorOperario: true,
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CABECERA DE ESPECIALIDAD ─────────────────────────
        GestureDetector(
          onTap: widget.partes.isEmpty
              ? null // No se expande si no hay partes.
              : () => setState(() => _expandido = !_expandido),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                // Flecha expandir/colapsar.
                Icon(
                  widget.partes.isEmpty
                      ? Icons.keyboard_arrow_right
                      : _expandido
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: widget.partes.isEmpty ? cardBorder : textSecondary,
                ),
                const SizedBox(width: 4),
                // Icono de la especialidad.
                Icon(
                  widget.icono,
                  size: 15,
                  color: widget.partes.isEmpty ? cardBorder : textSecondary,
                ),
                const SizedBox(width: 6),
                // Nombre de la especialidad.
                Text(
                  widget.titulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.partes.isEmpty ? cardBorder : textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                // Pastilla con total de horas.
                if (widget.partes.isNotEmpty)
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
                // Cantidad de personas o "Sin partes".
                Text(
                  widget.partes.isEmpty
                      ? 'Sin partes'
                      : '$operariosUnicos persona(s)',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.partes.isEmpty ? cardBorder : textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── CONTENIDO EXPANDIDO ─────────────────────────────
        if (_expandido && widget.partes.isNotEmpty) contenido,
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── GRUPO POR OBRA (obra -> dia -> operarios) ─────────────────────────────────

/// Grupo expandible por obra dentro de una especialidad.
/// Muestra nombre de obra, total de horas. Al expandir, muestra
/// los partes agrupados por fecha con DayHeader.
class _ObraGroup extends StatefulWidget {
  final String obraNombre;
  final List<ParteTrabajo> partes;

  const _ObraGroup({required this.obraNombre, required this.partes});

  @override
  State<_ObraGroup> createState() => _ObraGroupState();
}

class _ObraGroupState extends State<_ObraGroup> {
  bool _expandido = true; // Por defecto expandido.

  @override
  Widget build(BuildContext context) {
    final totalHoras = widget.partes.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );
    final horasLabel = totalHoras == totalHoras.truncateToDouble()
        ? '${totalHoras.toInt()}h'
        : '${totalHoras.toStringAsFixed(1)}h';

    // Agrupa por fecha.
    final Map<String, List<ParteTrabajo>> porFecha = {};
    for (final p in widget.partes) {
      porFecha.putIfAbsent(fmtYMD(p.fecha), () => []).add(p);
    }
    final fechasOrdenadas = porFecha.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CABECERA DE OBRA ────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                // Flecha expandir/colapsar.
                Icon(
                  _expandido
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 16,
                  color: textSecondary,
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.business_outlined,
                  size: 14,
                  color: textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.obraNombre,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Pastilla con total de horas.
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
              ],
            ),
          ),
        ),
        // ── CONTENIDO EXPANDIDO ─────────────────────────────
        if (_expandido)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                for (final fechaKey in fechasOrdenadas)
                  DayHeader(
                    fecha: DateTime.parse(fechaKey),
                    partes: porFecha[fechaKey]!,
                    agruparPorOperario: true,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

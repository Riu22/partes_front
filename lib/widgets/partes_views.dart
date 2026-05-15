import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../helpers/tema_constants.dart';
import '../helpers/fecha_helpers.dart';
import '../models/parte_trabajo.dart';
import '../providers/partes_provider.dart';
import '../providers/auth_provider.dart';
import 'lista_partes.dart';
import 'card_parte_jefe.dart';
import 'day_header.dart';

class PartesNormalesView extends ConsumerWidget {
  final bool agruparPorOperario;

  const PartesNormalesView({super.key, required this.agruparPorOperario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    // El resumen semanal solo se muestra a operarios y encargados (no a jefes/gestores)
    final mostrarResumen =
        perfil?.esOperario == true || perfil?.esEncargado == true;

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
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
          itemCount: partes.length,
          itemBuilder: (context, index) => CardParteJefe(parte: partes[index]),
        );
      },
    );
  }
}

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
        // ── Mis partes por porcentaje (siempre visibles, primero) ──
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
                ...partes.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: CardParteJefe(parte: p),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 4),
        const Divider(color: cardBorder, height: 1),
        const SizedBox(height: 4),

        // ── Partes de la obra separados por especialidad (eléctrica / fontanería) ──
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

// ── Sección desplegable por especialidad ────────────────────────────────────

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
    final totalHoras = widget.partes.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );
    // Muestra horas sin decimales si es entero, o con 1 decimal si no
    final horasLabel = totalHoras == totalHoras.truncateToDouble()
        ? '${totalHoras.toInt()}h'
        : '${totalHoras.toStringAsFixed(1)}h';
    final operariosUnicos = widget.partes
        .map((p) => p.operarioNombreCompleto)
        .toSet()
        .length;

    Widget contenido;

    if (widget.agruparPorObra) {
      // Vista jefe de obra: agrupa partes por obra → dentro, por fecha → operarios
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
      // Vista normal: agrupa por fecha → dentro, por operario
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
        GestureDetector(
          onTap: widget.partes.isEmpty
              ? null
              : () => setState(() => _expandido = !_expandido),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
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
                Icon(
                  widget.icono,
                  size: 15,
                  color: widget.partes.isEmpty ? cardBorder : textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.titulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.partes.isEmpty ? cardBorder : textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
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
        if (_expandido && widget.partes.isNotEmpty) contenido,
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Grupo por obra (obra → día → operarios) ──────────────────────────────────

class _ObraGroup extends StatefulWidget {
  final String obraNombre;
  final List<ParteTrabajo> partes;

  const _ObraGroup({required this.obraNombre, required this.partes});

  @override
  State<_ObraGroup> createState() => _ObraGroupState();
}

class _ObraGroupState extends State<_ObraGroup> {
  bool _expandido = true;

  @override
  Widget build(BuildContext context) {
    final totalHoras = widget.partes.fold<double>(
      0,
      (s, p) => s + p.horasNormales,
    );
    // Muestra horas sin decimales si es entero, o con 1 decimal si no
    final horasLabel = totalHoras == totalHoras.truncateToDouble()
        ? '${totalHoras.toInt()}h'
        : '${totalHoras.toStringAsFixed(1)}h';

    // Agrupa partes de esta obra por fecha (orden descendente)
    final Map<String, List<ParteTrabajo>> porFecha = {};
    for (final p in widget.partes) {
      porFecha.putIfAbsent(fmtYMD(p.fecha), () => []).add(p);
    }
    final fechasOrdenadas = porFecha.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
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

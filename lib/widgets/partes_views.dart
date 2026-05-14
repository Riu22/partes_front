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

        // ── Partes de la obra separados por especialidad ──
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
                ),
                const SizedBox(height: 4),
                _SeccionEspecialidad(
                  titulo: 'Fontanería',
                  icono: Icons.water_drop_outlined,
                  partes: fontaneria,
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

  const _SeccionEspecialidad({
    required this.titulo,
    required this.icono,
    required this.partes,
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
    final horasLabel = totalHoras == totalHoras.truncateToDouble()
        ? '${totalHoras.toInt()}h'
        : '${totalHoras.toStringAsFixed(1)}h';
    final operariosUnicos = widget.partes
        .map((p) => p.operarioNombreCompleto)
        .toSet()
        .length;

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
        if (_expandido && widget.partes.isNotEmpty)
          Column(
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
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

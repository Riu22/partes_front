import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/ausencia_info.dart';
import '../../providers/admin_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_drawer.dart';

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  String _formatFecha(String fecha) {
    try {
      final parts = fecha.split('/');
      final dt = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      return DateFormat('EEE d MMM', 'es').format(dt);
    } catch (_) {
      return fecha;
    }
  }

  /// Convierte "dd/MM/yyyy" → "yyyy-MM-dd" para pasarlo por la ruta
  String _fechaParaRuta(String fecha) {
    try {
      final parts = fecha.split('/');
      return '${parts[2]}-${parts[1]}-${parts[0]}';
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ausenciasAsync = ref.watch(diasSinParteProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(diasSinParteProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(diasSinParteProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Fecha actual
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  DateFormat(
                    "EEEE, d 'de' MMMM 'de' yyyy",
                    'es',
                  ).format(DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            // Tarjeta resumen
            SliverToBoxAdapter(
              child: ausenciasAsync.when(
                loading: () => const _ResumenCard(
                  cargando: true,
                  totalPersonas: 0,
                  totalSin: 0,
                  totalIncompletos: 0,
                ),
                error: (_, __) => const _ResumenCard(
                  cargando: false,
                  totalPersonas: 0,
                  totalSin: 0,
                  totalIncompletos: 0,
                  hayError: true,
                ),
                data: (ausencias) {
                  final totalSin = ausencias.values.fold(
                    0,
                    (sum, a) => sum + a.diasSin.length,
                  );
                  final totalIncompletos = ausencias.values.fold(
                    0,
                    (sum, a) => sum + a.diasIncompletos.length,
                  );
                  return _ResumenCard(
                    cargando: false,
                    totalPersonas: ausencias.length,
                    totalSin: totalSin,
                    totalIncompletos: totalIncompletos,
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Título sección
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Incidencias — quincena actual',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Contenido
            ausenciasAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: _ErrorView(
                  mensaje: 'Error al cargar ausencias: $error',
                  onRetry: () => ref.invalidate(diasSinParteProvider),
                ),
              ),
              data: (ausencias) {
                if (ausencias.isEmpty) {
                  return const SliverFillRemaining(child: _EmptyView());
                }
                final lista = ausencias.values.toList();
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _AusenciaCard(
                      ausencia: lista[index],
                      formatFecha: _formatFecha,
                      onHabilitarFecha: (perfilId, fecha) async {
                        final dt = DateTime.parse(_fechaParaRuta(fecha));
                        try {
                          await ApiService().habilitarFechas(perfilId, [dt]);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Fecha $fecha habilitada correctamente',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            ref.invalidate(diasSinParteProvider);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      onCrearParte: (perfilId, nombre, fecha) {
                        context.go(
                          '/partes/nuevo',
                          extra: {
                            'perfilId': perfilId,
                            'nombre': nombre,
                            'fecha': _fechaParaRuta(fecha),
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tarjeta resumen
// ─────────────────────────────────────────────

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.cargando,
    required this.totalPersonas,
    required this.totalSin,
    required this.totalIncompletos,
    this.hayError = false,
  });

  final bool cargando;
  final bool hayError;
  final int totalPersonas;
  final int totalSin;
  final int totalIncompletos;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String subtitulo;
    if (cargando) {
      subtitulo = 'Cargando...';
    } else if (hayError) {
      subtitulo = 'No disponible';
    } else {
      final partesPersonas =
          '$totalPersonas ${totalPersonas == 1 ? 'persona' : 'personas'}';
      final partesSin =
          '$totalSin ${totalSin == 1 ? 'día sin parte' : 'días sin parte'}';
      final partesInc =
          '$totalIncompletos ${totalIncompletos == 1 ? 'día incompleto' : 'días incompletos'}';
      subtitulo = '$partesPersonas · $partesSin · $partesInc';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        color: colorScheme.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 36,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incidencias detectadas',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tarjeta por persona
// ─────────────────────────────────────────────

class _AusenciaCard extends StatefulWidget {
  const _AusenciaCard({
    required this.ausencia,
    required this.formatFecha,
    required this.onHabilitarFecha,
    required this.onCrearParte,
  });

  final AusenciaInfo ausencia;
  final String Function(String) formatFecha;
  final Future<void> Function(String perfilId, String fecha) onHabilitarFecha;
  final void Function(String perfilId, String nombre, String fecha)
  onCrearParte;

  @override
  State<_AusenciaCard> createState() => _AusenciaCardState();
}

class _AusenciaCardState extends State<_AusenciaCard> {
  String? _fechaActiva;
  bool _habilitando = false;

  void _toggleFecha(String fecha) {
    setState(() => _fechaActiva = _fechaActiva == fecha ? null : fecha);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ausencia = widget.ausencia;
    final nombre = ausencia.nombre;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ──
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nombre,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${ausencia.totalIncidencias} '
                    '${ausencia.totalIncidencias == 1 ? 'incidencia' : 'incidencias'}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // ── Días sin parte ──
            if (ausencia.diasSin.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionLabel(
                icon: Icons.cancel_outlined,
                label: 'Sin parte (${ausencia.diasSin.length})',
                color: colorScheme.error,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ausencia.diasSin.map((fecha) {
                  final activa = _fechaActiva == fecha;
                  return _ChipConAcciones(
                    label: widget.formatFecha(fecha),
                    activa: activa,
                    habilitando: activa && _habilitando,
                    chipColor: colorScheme.errorContainer,
                    chipTextColor: colorScheme.onErrorContainer,
                    onTap: () => _toggleFecha(fecha),
                    onHabilitar: () async {
                      setState(() => _habilitando = true);
                      await widget.onHabilitarFecha(ausencia.perfilId, fecha);
                      if (mounted) {
                        setState(() {
                          _habilitando = false;
                          _fechaActiva = null;
                        });
                      }
                    },
                    onCrearParte: () {
                      setState(() => _fechaActiva = null);
                      widget.onCrearParte(ausencia.perfilId, nombre, fecha);
                    },
                  );
                }).toList(),
              ),
            ],

            // ── Días incompletos ──
            if (ausencia.diasIncompletos.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionLabel(
                icon: Icons.schedule_outlined,
                label: 'Horas incompletas (${ausencia.diasIncompletos.length})',
                color: colorScheme.tertiary,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ausencia.diasIncompletos.map((d) {
                  final activa = _fechaActiva == d.fecha;
                  return _ChipConAcciones(
                    label: '${widget.formatFecha(d.fecha)} · ${d.horas}h',
                    activa: activa,
                    habilitando: activa && _habilitando,
                    chipColor: colorScheme.tertiaryContainer,
                    chipTextColor: colorScheme.onTertiaryContainer,
                    onTap: () => _toggleFecha(d.fecha),
                    onHabilitar: () async {
                      setState(() => _habilitando = true);
                      await widget.onHabilitarFecha(ausencia.perfilId, d.fecha);
                      if (mounted) {
                        setState(() {
                          _habilitando = false;
                          _fechaActiva = null;
                        });
                      }
                    },
                    onCrearParte: () {
                      setState(() => _fechaActiva = null);
                      widget.onCrearParte(ausencia.perfilId, nombre, d.fecha);
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Chip con menú de acciones inline
// ─────────────────────────────────────────────

class _ChipConAcciones extends StatelessWidget {
  const _ChipConAcciones({
    required this.label,
    required this.activa,
    required this.habilitando,
    required this.chipColor,
    required this.chipTextColor,
    required this.onTap,
    required this.onHabilitar,
    required this.onCrearParte,
  });

  final String label;
  final bool activa;
  final bool habilitando;
  final Color chipColor;
  final Color chipTextColor;
  final VoidCallback onTap;
  final VoidCallback onHabilitar;
  final VoidCallback onCrearParte;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // El chip
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: activa ? colorScheme.inverseSurface : chipColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: activa
                        ? colorScheme.onInverseSurface
                        : chipTextColor,
                    fontWeight: activa ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  activa
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: activa ? colorScheme.onInverseSurface : chipTextColor,
                ),
              ],
            ),
          ),
        ),

        // Menú inline expandible con AnimatedSize
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: activa
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Opción: Habilitar día
                          InkWell(
                            onTap: habilitando ? null : onHabilitar,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (habilitando)
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.lock_open_rounded,
                                      size: 15,
                                      color: colorScheme.primary,
                                    ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Habilitar día',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 1, color: colorScheme.outlineVariant),
                          // Opción: Crear parte
                          InkWell(
                            onTap: onCrearParte,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 15,
                                    color: colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Crear parte',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.tertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Estado vacío
// ─────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin incidencias',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Todos los operarios tienen parte\nen la quincena actual.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Estado de error
// ─────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.mensaje, required this.onRetry});

  final String mensaje;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

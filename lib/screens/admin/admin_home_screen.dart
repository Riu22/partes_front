import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/app_drawer.dart';

// Modelos

class DiaIncompleto {
  final String fecha;
  final String horas;

  const DiaIncompleto({required this.fecha, required this.horas});
}

class AusenciaInfo {
  final String nombre;
  final List<String> diasSin;
  final List<DiaIncompleto> diasIncompletos;
  final int totalLaborables;

  const AusenciaInfo({
    required this.nombre,
    required this.diasSin,
    required this.diasIncompletos,
    required this.totalLaborables,
  });

  int get totalIncidencias => diasSin.length + diasIncompletos.length;
}

// Provider

final diasSinParteProvider =
    FutureProvider.autoDispose<Map<String, AusenciaInfo>>((ref) async {
      final api = ApiService();
      final raw = await api.getDiasSinParte();

      return raw.map((uuid, value) {
        final info = value as Map<String, dynamic>;

        final diasSin = (info['diasSin'] as List)
            .map((e) => e.toString())
            .toList();

        final diasIncompletos = (info['diasIncompletos'] as List).map((e) {
          final m = e as Map<String, dynamic>;
          return DiaIncompleto(
            fecha: m['fecha'] as String,
            horas: m['horas'] as String,
          );
        }).toList();

        return MapEntry(
          uuid,
          AusenciaInfo(
            nombre: info['nombre'] as String,
            diasSin: diasSin,
            diasIncompletos: diasIncompletos,
            totalLaborables: info['totalLaborables'] as int,
          ),
        );
      });
    });

// Screen

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

class _AusenciaCard extends StatelessWidget {
  const _AusenciaCard({required this.ausencia, required this.formatFecha});

  final AusenciaInfo ausencia;
  final String Function(String) formatFecha;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
            // Cabecera
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

            // Sección: días sin parte
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
                children: ausencia.diasSin
                    .map(
                      (fecha) => _FechaChip(
                        label: formatFecha(fecha),
                        backgroundColor: colorScheme.errorContainer,
                        foregroundColor: colorScheme.onErrorContainer,
                      ),
                    )
                    .toList(),
              ),
            ],

            // Sección: días incompletos
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
                children: ausencia.diasIncompletos
                    .map(
                      (d) => _FechaChip(
                        label: '${formatFecha(d.fecha)} · ${d.horas}h',
                        backgroundColor: colorScheme.tertiaryContainer,
                        foregroundColor: colorScheme.onTertiaryContainer,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Widgets auxiliares

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

class _FechaChip extends StatelessWidget {
  const _FechaChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: foregroundColor),
      backgroundColor: backgroundColor,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
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

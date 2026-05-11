import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../widgets/app_drawer.dart';

// ─────────────────────────────────────────
// Provider
// ─────────────────────────────────────────

final diasSinParteProvider = FutureProvider.autoDispose<Map<String, List<String>>>((
  ref,
) async {
  final api = ApiService();
  final raw = await api.getDiasSinParte();
  // El backend devuelve Map<uuid, {nombre, diasSin, totalSin, totalLaborables}>
  return raw.map((uuid, value) {
    final info = value as Map<String, dynamic>;
    final diasSin = (info['diasSin'] as List).map((e) => e.toString()).toList();
    return MapEntry(info['nombre'] as String, diasSin);
  });
});

// ─────────────────────────────────────────
// Screen
// ─────────────────────────────────────────

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  String _formatFecha(String fecha) {
    try {
      // El backend devuelve fechas en formato dd/MM/yyyy
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
            // ── Fecha actual ──
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

            // ── Tarjeta resumen ──
            SliverToBoxAdapter(
              child: ausenciasAsync.when(
                loading: () => const _ResumenCard(
                  cargando: true,
                  totalPersonas: 0,
                  totalDias: 0,
                ),
                error: (_, __) => const _ResumenCard(
                  cargando: false,
                  totalPersonas: 0,
                  totalDias: 0,
                  hayError: true,
                ),
                data: (ausencias) => _ResumenCard(
                  cargando: false,
                  totalPersonas: ausencias.length,
                  totalDias: ausencias.values.fold(
                    0,
                    (sum, dias) => sum + dias.length,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Título sección ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Días sin parte — quincena actual',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // ── Contenido ──
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
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: ausencias.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final nombre = ausencias.keys.elementAt(index);
                      final dias = ausencias[nombre]!;
                      return _AusenciaCard(
                        nombre: nombre,
                        dias: dias,
                        formatFecha: _formatFecha,
                      );
                    },
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

// ─────────────────────────────────────────
// Tarjeta resumen
// ─────────────────────────────────────────

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.cargando,
    required this.totalPersonas,
    required this.totalDias,
    this.hayError = false,
  });

  final bool cargando;
  final bool hayError;
  final int totalPersonas;
  final int totalDias;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                      'Ausencias detectadas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cargando
                          ? 'Cargando...'
                          : hayError
                          ? 'No disponible'
                          : '$totalPersonas ${totalPersonas == 1 ? 'persona' : 'personas'} · '
                                '$totalDias ${totalDias == 1 ? 'día' : 'días'} sin parte',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

// ─────────────────────────────────────────
// Tarjeta por persona
// ─────────────────────────────────────────

class _AusenciaCard extends StatelessWidget {
  const _AusenciaCard({
    required this.nombre,
    required this.dias,
    required this.formatFecha,
  });

  final String nombre;
  final List<String> dias;
  final String Function(String) formatFecha;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    '${dias.length} ${dias.length == 1 ? 'día' : 'días'}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: dias
                  .map(
                    (fecha) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(formatFecha(fecha)),
                      labelStyle: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                      backgroundColor: colorScheme.secondaryContainer,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Estado vacío
// ─────────────────────────────────────────

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
            'Sin ausencias',
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

// ─────────────────────────────────────────
// Estado de error
// ─────────────────────────────────────────

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

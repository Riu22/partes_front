import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/ausencia_info.dart';
import '../../providers/admin_provider.dart';
import '../../providers/obras_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/buscador_obras_modal.dart';
import '../../widgets/buscador_operarios_modal.dart';

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
    final obrasAsync = ref.watch(obrasProvider);
    final obras = obrasAsync.valueOrNull ?? [];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.assignment_late_outlined), text: 'Partes'),
              Tab(icon: Icon(Icons.event_busy_rounded), text: 'Ausencias'),
              Tab(icon: Icon(Icons.work_outline_rounded), text: 'Historial'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PartesTab(
              ausenciasAsync: ausenciasAsync,
              formatFecha: _formatFecha,
              fechaParaRuta: _fechaParaRuta,
              ref: ref,
              obras: obras,
            ),
            _AusenciasTab(
              ausenciasAsync: ausenciasAsync,
              formatFecha: _formatFecha,
              ref: ref,
              obras: obras,
            ),
            _HistorialTab(obras: obras, ref: ref),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pestaña 1 — Partes
// ─────────────────────────────────────────────

class _PartesTab extends StatelessWidget {
  const _PartesTab({
    required this.ausenciasAsync,
    required this.formatFecha,
    required this.fechaParaRuta,
    required this.ref,
    required this.obras,
  });

  final AsyncValue<Map<String, AusenciaInfo>> ausenciasAsync;
  final String Function(String) formatFecha;
  final String Function(String) fechaParaRuta;
  final WidgetRef ref;
  final List obras;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(diasSinParteProvider),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'es')
                    .format(DateTime.now()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ausenciasAsync.when(
              loading: () => const _ResumenPartes(
                cargando: true,
                totalPersonas: 0,
                totalSin: 0,
                totalIncompletos: 0,
              ),
              error: (_, __) => const _ResumenPartes(
                cargando: false,
                totalPersonas: 0,
                totalSin: 0,
                totalIncompletos: 0,
                hayError: true,
              ),
              data: (ausencias) {
                final conPartes = ausencias.values
                    .where((a) =>
                        a.diasSin.isNotEmpty || a.diasIncompletos.isNotEmpty)
                    .toList();
                final fechasSin =
                    conPartes.expand((a) => a.diasSin).toSet();
                final fechasInc = conPartes
                    .expand((a) => a.diasIncompletos.map((d) => d.fecha))
                    .toSet();
                return _ResumenPartes(
                  cargando: false,
                  totalPersonas: conPartes.length,
                  totalSin: fechasSin.length,
                  totalIncompletos: fechasInc.length,
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Incidencias de partes — histórico completo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          ausenciasAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: _ErrorView(
                mensaje: 'Error al cargar datos: $error',
                onRetry: () => ref.invalidate(diasSinParteProvider),
              ),
            ),
            data: (ausencias) {
              final lista = ausencias.values
                  .where((a) =>
                      a.diasSin.isNotEmpty || a.diasIncompletos.isNotEmpty)
                  .toList();

              if (lista.isEmpty) {
                return const SliverFillRemaining(
                  child: _EmptyView(
                    mensaje: 'Todos los operarios tienen\nsus partes al día.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _AusenciaCard(
                    ausencia: lista[index],
                    formatFecha: formatFecha,
                    mostrarAusencias: false,
                    onHabilitarFecha: (perfilId, fecha) async {
                      final dt = DateTime.parse(fechaParaRuta(fecha));
                      try {
                        await ApiService().habilitarFechas(perfilId, [dt]);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Fecha $fecha habilitada correctamente'),
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
                          'fecha': fechaParaRuta(fecha),
                        },
                      );
                    },
                    onRegistrarAusencia: (perfilId, nombre) async {
                      await showDialog(
                        context: context,
                        builder: (_) => _DialogoAusencia(
                          perfilId: perfilId,
                          nombre: nombre,
                          obras: obras,
                          onGuardar: (tipo, inicio, fin, obs, obraId) async {
                            await ApiService().crearAusenciaLaboral(
                              perfilId: perfilId,
                              tipo: tipo,
                              fechaInicio: inicio,
                              fechaFin: fin,
                              observaciones: obs,
                              obraId: obraId,
                            );
                            ref.invalidate(diasSinParteProvider);
                          },
                        ),
                      );
                    },
                    onEditarAusencia: null,
                    onEliminarAusencia: null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pestaña 2 — Ausencias laborales
// ─────────────────────────────────────────────

class _AusenciasTab extends StatelessWidget {
  const _AusenciasTab({
    required this.ausenciasAsync,
    required this.formatFecha,
    required this.ref,
    required this.obras,
  });

  final AsyncValue<Map<String, AusenciaInfo>> ausenciasAsync;
  final String Function(String) formatFecha;
  final WidgetRef ref;
  final List obras;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(diasSinParteProvider),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Ausencias laborales registradas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          ausenciasAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: _ErrorView(
                mensaje: 'Error al cargar datos: $error',
                onRetry: () => ref.invalidate(diasSinParteProvider),
              ),
            ),
            data: (ausencias) {
              final lista = ausencias.values
                  .where((a) => a.ausenciasActivas.isNotEmpty)
                  .toList();

              if (lista.isEmpty) {
                return const SliverFillRemaining(
                  child: _EmptyView(
                    icono: Icons.beach_access_rounded,
                    mensaje: 'No hay ausencias\nlaborales registradas.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _AusenciaCard(
                    ausencia: lista[index],
                    formatFecha: formatFecha,
                    mostrarAusencias: true,
                    onHabilitarFecha: null,
                    onCrearParte: null,
                    onRegistrarAusencia: (perfilId, nombre) async {
                      await showDialog(
                        context: context,
                        builder: (_) => _DialogoAusencia(
                          perfilId: perfilId,
                          nombre: nombre,
                          obras: obras,
                          onGuardar: (tipo, inicio, fin, obs, obraId) async {
                            await ApiService().crearAusenciaLaboral(
                              perfilId: perfilId,
                              tipo: tipo,
                              fechaInicio: inicio,
                              fechaFin: fin,
                              observaciones: obs,
                              obraId: obraId,
                            );
                            ref.invalidate(diasSinParteProvider);
                          },
                        ),
                      );
                    },
                    onEditarAusencia: (ausencia, perfilId, nombre) async {
                      await showDialog(
                        context: context,
                        builder: (_) => _DialogoAusencia(
                          perfilId: perfilId,
                          nombre: nombre,
                          obras: obras,
                          ausenciaExistente: ausencia,
                          onGuardar: (tipo, inicio, fin, obs, obraId) async {
                            await ApiService()
                                .eliminarAusenciaLaboral(ausencia.id!);
                            await ApiService().crearAusenciaLaboral(
                              perfilId: perfilId,
                              tipo: tipo,
                              fechaInicio: inicio,
                              fechaFin: fin,
                              observaciones: obs,
                              obraId: obraId,
                            );
                            ref.invalidate(diasSinParteProvider);
                          },
                        ),
                      );
                    },
                    // ── CAMBIO PRINCIPAL: eliminación optimista ──────────
                    onEliminarAusencia: (ausenciaId) async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Eliminar ausencia'),
                          content: const Text(
                              '¿Seguro que quieres eliminar esta ausencia?'),
                          actions: [
TextButton(
  onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
  child: const Text('Cancelar'),
),
FilledButton(
  onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );

                      if (confirmar != true || !context.mounted) return;

                      // 1️⃣ Actualización optimista: quitamos la ausencia
                      //    del estado local ANTES de llamar al servidor.
                      //    La UI se actualiza de inmediato sin parpadeo.
                      ref
                          .read(diasSinParteProvider.notifier)
                          .eliminarAusenciaLocal(ausenciaId);

                      try {
                        // 2️⃣ Llamada real al servidor
                        await ApiService()
                            .eliminarAusenciaLaboral(ausenciaId);

                        // 3️⃣ Sincronización en segundo plano (silenciosa,
                        //    no provoca spinner porque el estado ya es AsyncData)
                        ref.invalidate(diasSinParteProvider);
                      } catch (e) {
                        // 4️⃣ Si falla, recargamos para revertir el estado optimista
                        ref.invalidate(diasSinParteProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al eliminar: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tarjeta resumen
// ─────────────────────────────────────────────

class _ResumenPartes extends StatelessWidget {
  const _ResumenPartes({
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
    } else if (totalPersonas == 0) {
      subtitulo = 'Sin incidencias de partes';
    } else {
      final p =
          '$totalPersonas ${totalPersonas == 1 ? 'persona' : 'personas'}';
      final s =
          '$totalSin ${totalSin == 1 ? 'día sin parte' : 'días sin parte'}';
      final i =
          '$totalIncompletos ${totalIncompletos == 1 ? 'día incompleto' : 'días incompletos'}';
      subtitulo = '$p · $s · $i';
    }

    final sinIncidencias = !cargando && !hayError && totalPersonas == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        color: sinIncidencias
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                sinIncidencias
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 36,
                color: sinIncidencias
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sinIncidencias ? 'Todo al día' : 'Partes pendientes',
                      style: textTheme.titleMedium?.copyWith(
                        color: sinIncidencias
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: textTheme.bodyMedium?.copyWith(
                        color: sinIncidencias
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onErrorContainer,
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
    required this.mostrarAusencias,
    required this.onHabilitarFecha,
    required this.onCrearParte,
    required this.onRegistrarAusencia,
    required this.onEditarAusencia,
    required this.onEliminarAusencia,
  });

  final AusenciaInfo ausencia;
  final String Function(String) formatFecha;
  final bool mostrarAusencias;
  final Future<void> Function(String perfilId, String fecha)? onHabilitarFecha;
  final void Function(String perfilId, String nombre, String fecha)?
      onCrearParte;
  final Future<void> Function(String perfilId, String nombre)?
      onRegistrarAusencia;
  final Future<void> Function(
          AusenciaLaboral ausencia, String perfilId, String nombre)?
      onEditarAusencia;
  final Future<void> Function(int ausenciaId)? onEliminarAusencia;

  @override
  State<_AusenciaCard> createState() => _AusenciaCardState();
}

class _AusenciaCardState extends State<_AusenciaCard> {
  String? _fechaActiva;
  int? _ausenciaActivaId;
  bool _habilitando = false;

  void _toggleFecha(String fecha) => setState(() {
        _fechaActiva = _fechaActiva == fecha ? null : fecha;
        _ausenciaActivaId = null;
      });

  void _toggleAusencia(int id) => setState(() {
        _ausenciaActivaId = _ausenciaActivaId == id ? null : id;
        _fechaActiva = null;
      });

  Color _colorFondoAusencia(String tipo, ColorScheme cs) => switch (tipo) {
        'BAJA' => cs.errorContainer,
        'VACACIONES' => cs.secondaryContainer,
        'PATERNIDAD' => const Color(0xFFBFDBFE),
        _ => cs.surfaceVariant,
      };

  Color _colorTextoAusencia(String tipo, ColorScheme cs) => switch (tipo) {
        'BAJA' => cs.error,
        'VACACIONES' => cs.secondary,
        'PATERNIDAD' => const Color(0xFF1D4ED8),
        _ => cs.onSurfaceVariant,
      };

  IconData _iconoAusencia(String tipo) => switch (tipo) {
        'BAJA' => Icons.local_hospital_rounded,
        'VACACIONES' => Icons.beach_access_rounded,
        'PATERNIDAD' => Icons.child_friendly_rounded,
        _ => Icons.event_busy_rounded,
      };

  String _labelAusencia(String tipo) => switch (tipo) {
        'BAJA' => 'Baja',
        'VACACIONES' => 'Vacaciones',
        'PATERNIDAD' => 'Paternidad',
        _ => tipo,
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ausencia = widget.ausencia;
    final nombre = ausencia.nombre;

    final badgeCount = widget.mostrarAusencias
        ? ausencia.ausenciasActivas.length
        : ausencia.diasSin.length + ausencia.diasIncompletos.length;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ─────────────────────────────────────────────────
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
                    style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.mostrarAusencias
                        ? colorScheme.secondaryContainer
                        : colorScheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.mostrarAusencias
                        ? '$badgeCount ${badgeCount == 1 ? 'ausencia' : 'ausencias'}'
                        : '$badgeCount ${badgeCount == 1 ? 'incidencia' : 'incidencias'}',
                    style: textTheme.labelSmall?.copyWith(
                      color: widget.mostrarAusencias
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // ── Ausencias laborales ──────────────────────────────────────
            if (widget.mostrarAusencias &&
                ausencia.ausenciasActivas.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionLabel(
                icon: Icons.event_busy_rounded,
                label: 'Ausencias registradas',
                color: colorScheme.secondary,
              ),
              const SizedBox(height: 6),
              ...ausencia.ausenciasActivas.map((a) {
                final expandida = _ausenciaActivaId == a.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _toggleAusencia(a.id!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: expandida
                                ? colorScheme.inverseSurface
                                : _colorFondoAusencia(a.tipo, colorScheme),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconoAusencia(a.tipo),
                                  size: 14,
                                  color: expandida
                                      ? colorScheme.onInverseSurface
                                      : _colorTextoAusencia(
                                          a.tipo, colorScheme)),
                              const SizedBox(width: 6),
                              Text(
                                '${_labelAusencia(a.tipo)}  '
                                '${widget.formatFecha(a.fechaInicio)} → '
                                '${widget.formatFecha(a.fechaFin)}',
                                style: textTheme.labelSmall?.copyWith(
                                  color: expandida
                                      ? colorScheme.onInverseSurface
                                      : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (a.observaciones != null &&
                                  a.observaciones!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '· ${a.observaciones}',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: expandida
                                          ? colorScheme.onInverseSurface
                                              .withOpacity(0.7)
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 4),
                              Icon(
                                expandida
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: expandida
                                    ? colorScheme.onInverseSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeInOut,
                        child: expandida
                            ? Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: colorScheme.outlineVariant),
                                  ),
                                  child: IntrinsicWidth(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (widget.onEditarAusencia != null)
                                          InkWell(
                                            onTap: () {
                                              setState(() =>
                                                  _ausenciaActivaId = null);
                                              widget.onEditarAusencia!(
                                                  a,
                                                  ausencia.perfilId,
                                                  nombre);
                                            },
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    top: Radius.circular(10)),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.edit_rounded,
                                                      size: 15,
                                                      color:
                                                          colorScheme.primary),
                                                  const SizedBox(width: 6),
                                                  Text('Editar ausencia',
                                                      style: textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                        color:
                                                            colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      )),
                                                ],
                                              ),
                                            ),
                                          ),
                                        Divider(
                                            height: 1,
                                            color:
                                                colorScheme.outlineVariant),
                                        if (widget.onEliminarAusencia != null)
                                          InkWell(
                                            onTap: () {
                                              setState(() =>
                                                  _ausenciaActivaId = null);
                                              widget.onEliminarAusencia!(
                                                  a.id!);
                                            },
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                    bottom:
                                                        Radius.circular(10)),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.delete_rounded,
                                                      size: 15,
                                                      color:
                                                          colorScheme.error),
                                                  const SizedBox(width: 6),
                                                  Text('Eliminar ausencia',
                                                      style: textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                        color:
                                                            colorScheme.error,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      )),
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
                  ),
                );
              }),
            ],

            // ── Días sin parte ───────────────────────────────────────────
            if (!widget.mostrarAusencias &&
                ausencia.diasSin.isNotEmpty) ...[
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
                    estaHabilitada:
                        ausencia.fechasHabilitadas.contains(fecha),
                    chipColor: colorScheme.errorContainer,
                    chipTextColor: colorScheme.onErrorContainer,
                    onTap: () => _toggleFecha(fecha),
                    onHabilitar: widget.onHabilitarFecha == null
                        ? null
                        : () async {
                            setState(() => _habilitando = true);
                            await widget.onHabilitarFecha!(
                                ausencia.perfilId, fecha);
                            if (mounted) {
                              setState(() {
                                _habilitando = false;
                                _fechaActiva = null;
                              });
                            }
                          },
                    onCrearParte: widget.onCrearParte == null
                        ? null
                        : () {
                            setState(() => _fechaActiva = null);
                            widget.onCrearParte!(
                                ausencia.perfilId, nombre, fecha);
                          },
                  );
                }).toList(),
              ),
            ],

            // ── Días incompletos ─────────────────────────────────────────
            if (!widget.mostrarAusencias &&
                ausencia.diasIncompletos.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SectionLabel(
                icon: Icons.schedule_outlined,
                label:
                    'Horas incompletas (${ausencia.diasIncompletos.length})',
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
                    estaHabilitada:
                        ausencia.fechasHabilitadas.contains(d.fecha),
                    chipColor: colorScheme.tertiaryContainer,
                    chipTextColor: colorScheme.onTertiaryContainer,
                    onTap: () => _toggleFecha(d.fecha),
                    onHabilitar: widget.onHabilitarFecha == null
                        ? null
                        : () async {
                            setState(() => _habilitando = true);
                            await widget.onHabilitarFecha!(
                                ausencia.perfilId, d.fecha);
                            if (mounted) {
                              setState(() {
                                _habilitando = false;
                                _fechaActiva = null;
                              });
                            }
                          },
                    onCrearParte: widget.onCrearParte == null
                        ? null
                        : () {
                            setState(() => _fechaActiva = null);
                            widget.onCrearParte!(
                                ausencia.perfilId, nombre, d.fecha);
                          },
                  );
                }).toList(),
              ),
            ],

            // ── Botón registrar ausencia ─────────────────────────────────
            if (widget.onRegistrarAusencia != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => widget.onRegistrarAusencia!(
                      ausencia.perfilId, nombre),
                  icon: const Icon(Icons.event_busy_rounded, size: 16),
                  label: const Text('Registrar baja / vacaciones'),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Diálogo registrar / editar ausencia
// ─────────────────────────────────────────────

class _DialogoAusencia extends StatefulWidget {
  const _DialogoAusencia({
    required this.perfilId,
    required this.nombre,
    required this.obras,
    required this.onGuardar,
    this.ausenciaExistente,
  });

  final String perfilId;
  final String nombre;
  final List obras;
  final AusenciaLaboral? ausenciaExistente;
  final Future<void> Function(
      String tipo,
      DateTime inicio,
      DateTime fin,
      String? obs,
      int? obraId) onGuardar;

  @override
  State<_DialogoAusencia> createState() => _DialogoAusenciaState();
}

class _DialogoAusenciaState extends State<_DialogoAusencia> {
  late String _tipo;
  DateTime? _inicio;
  DateTime? _fin;
  late final TextEditingController _obsController;
  bool _guardando = false;
  String? _error;
  dynamic _obraSeleccionada;

  @override
  void initState() {
    super.initState();
    final a = widget.ausenciaExistente;
    _tipo = a?.tipo ?? 'BAJA';
    _obsController = TextEditingController(text: a?.observaciones ?? '');
    if (a != null) {
      _inicio = _parseFecha(a.fechaInicio);
      _fin = _parseFecha(a.fechaFin);
    }
  }

  DateTime? _parseFecha(String ddMMyyyy) {
    try {
      final p = ddMMyyyy.split('/');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha({required bool esInicio}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (esInicio ? _inicio : _fin) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (esInicio) {
        _inicio = picked;
        if (_fin != null && _fin!.isBefore(_inicio!)) _fin = null;
      } else {
        _fin = picked;
      }
    });
  }

  void _seleccionarObra() {
    abrirBuscadorObras(context, widget.obras, (obra) {
      setState(() => _obraSeleccionada = obra);
    });
  }

  Future<void> _guardar() async {
    if (_inicio == null || _fin == null) {
      setState(() => _error = 'Selecciona las fechas de inicio y fin');
      return;
    }
    if (_fin!.isBefore(_inicio!)) {
      setState(
          () => _error = 'La fecha fin no puede ser anterior al inicio');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final obraId = (_tipo == 'VACACIONES' && _obraSeleccionada != null)
          ? _obraSeleccionada.id as int?
          : null;

      await widget.onGuardar(
        _tipo,
        _inicio!,
        _fin!,
        _obsController.text.trim().isEmpty
            ? null
            : _obsController.text.trim(),
        obraId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fmt = DateFormat('dd/MM/yyyy', 'es');
    final esEdicion = widget.ausenciaExistente != null;

    return AlertDialog(
      title: Text(
        esEdicion ? 'Editar ausencia' : 'Registrar ausencia',
        style: textTheme.titleMedium,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nombre,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // ── Selector de tipo ──────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TipoChip(
                  label: 'Baja',
                  icon: Icons.local_hospital_rounded,
                  seleccionado: _tipo == 'BAJA',
                  color: colorScheme.error,
                  onTap: () => setState(() {
                    _tipo = 'BAJA';
                    _obraSeleccionada = null;
                  }),
                ),
                _TipoChip(
                  label: 'Vacaciones',
                  icon: Icons.beach_access_rounded,
                  seleccionado: _tipo == 'VACACIONES',
                  color: colorScheme.secondary,
                  onTap: () => setState(() => _tipo = 'VACACIONES'),
                ),
                _TipoChip(
                  label: 'Paternidad',
                  icon: Icons.child_friendly_rounded,
                  seleccionado: _tipo == 'PATERNIDAD',
                  color: const Color(0xFF1D4ED8),
                  onTap: () => setState(() {
                    _tipo = 'PATERNIDAD';
                    _obraSeleccionada = null;
                  }),
                ),
              ],
            ),

            // ── Selector de obra (solo VACACIONES) ────────────────────────
            if (_tipo == 'VACACIONES') ...[
              const SizedBox(height: 12),
              if (_obraSeleccionada == null)
                OutlinedButton.icon(
                  onPressed: _seleccionarObra,
                  icon: const Icon(Icons.business_outlined,
                      size: 16, color: Colors.orange),
                  label: const Text(
                    'Asignar obra (opcional)',
                    style: TextStyle(color: Colors.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _obraSeleccionada.nombre ?? '',
                              style: textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if ((_obraSeleccionada.municipio ?? '')
                                .isNotEmpty)
                              Text(
                                _obraSeleccionada.municipio ?? '',
                                style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz,
                            color: Colors.orange, size: 18),
                        tooltip: 'Cambiar obra',
                        onPressed: _seleccionarObra,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.grey, size: 18),
                        tooltip: 'Quitar obra (imputar a oficina)',
                        onPressed: () =>
                            setState(() => _obraSeleccionada = null),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 16),

            // ── Fechas ───────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _FechaBoton(
                    label: 'Desde',
                    fecha: _inicio != null ? fmt.format(_inicio!) : null,
                    onTap: () => _seleccionarFecha(esInicio: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FechaBoton(
                    label: 'Hasta',
                    fecha: _fin != null ? fmt.format(_fin!) : null,
                    onTap: () => _seleccionarFecha(esInicio: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Observaciones ────────────────────────────────────────────
            TextField(
              controller: _obsController,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(esEdicion ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Chip con acciones inline
// ─────────────────────────────────────────────

class _ChipConAcciones extends StatefulWidget {
  const _ChipConAcciones({
    required this.label,
    required this.activa,
    required this.habilitando,
    required this.estaHabilitada,
    required this.chipColor,
    required this.chipTextColor,
    required this.onTap,
    required this.onHabilitar,
    required this.onCrearParte,
  });

  final String label;
  final bool activa;
  final bool habilitando;
  final bool estaHabilitada;
  final Color chipColor;
  final Color chipTextColor;
  final VoidCallback onTap;
  final VoidCallback? onHabilitar;
  final VoidCallback? onCrearParte;

  @override
  State<_ChipConAcciones> createState() => _ChipConAccionesState();
}

class _ChipConAccionesState extends State<_ChipConAcciones> {
  late bool _habilitado;

  @override
  void initState() {
    super.initState();
    _habilitado = widget.estaHabilitada;
  }

  @override
  void didUpdateWidget(_ChipConAcciones oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.estaHabilitada != widget.estaHabilitada) {
      _habilitado = widget.estaHabilitada;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _habilitado ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _habilitado
                  ? Colors.green.shade100
                  : widget.activa
                      ? colorScheme.inverseSurface
                      : widget.chipColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_habilitado) ...[
                  Icon(Icons.check_circle_rounded,
                      size: 13, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                ],
                Text(
                  _habilitado
                      ? '${widget.label} · Permitido'
                      : widget.label,
                  style: textTheme.labelSmall?.copyWith(
                    color: _habilitado
                        ? Colors.green.shade700
                        : widget.activa
                            ? colorScheme.onInverseSurface
                            : widget.chipTextColor,
                    fontWeight: widget.activa
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                if (!_habilitado) ...[
                  const SizedBox(width: 4),
                  Icon(
                    widget.activa
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: widget.activa
                        ? colorScheme.onInverseSurface
                        : widget.chipTextColor,
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: widget.activa && !_habilitado
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
                          if (widget.onHabilitar != null)
                            InkWell(
                              onTap: widget.habilitando
                                  ? null
                                  : () {
                                      setState(() => _habilitado = true);
                                      widget.onHabilitar!();
                                    },
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.habilitando)
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    else
                                      Icon(Icons.lock_open_rounded,
                                          size: 15,
                                          color: colorScheme.primary),
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
                          if (widget.onHabilitar != null &&
                              widget.onCrearParte != null)
                            Divider(
                                height: 1,
                                color: colorScheme.outlineVariant),
                          if (widget.onCrearParte != null)
                            InkWell(
                              onTap: widget.onCrearParte,
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_circle_outline_rounded,
                                        size: 15,
                                        color: colorScheme.tertiary),
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

class _TipoChip extends StatelessWidget {
  const _TipoChip({
    required this.label,
    required this.icon,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado
              ? color.withOpacity(0.15)
              : Colors.transparent,
          border: Border.all(
              color: seleccionado
                  ? color
                  : Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: seleccionado ? color : null),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: seleccionado ? color : null,
                    fontWeight: seleccionado ? FontWeight.bold : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FechaBoton extends StatelessWidget {
  const _FechaBoton({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  final String label;
  final String? fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_rounded, size: 14),
      label: Text(
        fecha ?? label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fecha != null
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
      ),
      style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
    );
  }
}

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

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    this.icono = Icons.check_circle_outline_rounded,
    required this.mensaje,
  });

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 64, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Sin incidencias',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            mensaje,
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

// ─────────────────────────────────────────────
// Pestaña 3 — Historial
// ─────────────────────────────────────────────

class _HistorialTab extends StatefulWidget {
  const _HistorialTab({required this.obras, required this.ref});
  final List obras;
  final WidgetRef ref;

  @override
  State<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends State<_HistorialTab> {
  dynamic _perfilSeleccionado;
  String? _perfilId;
  String? _nombre;

  void _buscarOperario() {
    abrirBuscadorOperarios(context, (perfil) {
      setState(() {
        _perfilSeleccionado = perfil;
        _perfilId = perfil.id.toString();
        _nombre = perfil.nombre;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _perfilSeleccionado == null
                ? OutlinedButton.icon(
                    onPressed: _buscarOperario,
                    icon: const Icon(Icons.person_search_rounded),
                    label: const Text('Seleccionar operario'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  )
                : ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        _nombre![0].toUpperCase(),
                        style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(_nombre!,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Historial de ausencias'),
                    trailing: TextButton(
                      onPressed: _buscarOperario,
                      child: const Text('Cambiar'),
                    ),
                  ),
          ),
        ),
        if (_perfilId == null)
          const SliverFillRemaining(
            child: _EmptyView(
              icono: Icons.manage_search_rounded,
              mensaje: 'Selecciona un operario para\nver su historial.',
            ),
          )
        else
          _HistorialBody(perfilId: _perfilId!, nombre: _nombre!),
      ],
    );
  }
}

class _HistorialBody extends ConsumerWidget {
  const _HistorialBody({required this.perfilId, required this.nombre});
  final String perfilId;
  final String nombre;

  String _formatFecha(String fecha) {
    try {
      final p = fecha.split('/');
      final dt = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      return DateFormat('dd MMM yyyy', 'es').format(dt);
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historialAusenciasProvider(perfilId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return historialAsync.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverFillRemaining(
        child: _ErrorView(
          mensaje: 'Error al cargar historial: $e',
          onRetry: () =>
              ref.invalidate(historialAusenciasProvider(perfilId)),
        ),
      ),
      data: (data) {
        final ausencias = (data['ausencias'] as List? ?? []);

        if (ausencias.isEmpty) {
          return const SliverFillRemaining(
            child: _EmptyView(
              icono: Icons.beach_access_rounded,
              mensaje: 'Este operario no tiene\nausencias registradas.',
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList.separated(
            itemCount: ausencias.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final a = ausencias[i] as Map<String, dynamic>;
              final tipo = a['tipo'] as String? ?? '';

              final (Color fondo, Color texto, IconData icono) =
                  switch (tipo) {
                'BAJA' => (
                    colorScheme.errorContainer,
                    colorScheme.error,
                    Icons.local_hospital_rounded
                  ),
                'VACACIONES' => (
                    colorScheme.secondaryContainer,
                    colorScheme.secondary,
                    Icons.beach_access_rounded
                  ),
                'PATERNIDAD' => (
                    const Color(0xFFBFDBFE),
                    const Color(0xFF1D4ED8),
                    Icons.child_friendly_rounded
                  ),
                _ => (
                    colorScheme.surfaceVariant,
                    colorScheme.onSurfaceVariant,
                    Icons.event_busy_rounded
                  ),
              };

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: fondo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(icono, size: 20, color: texto),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _labelTipo(tipo),
                            style: textTheme.labelMedium?.copyWith(
                                color: texto, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatFecha(a['fechaInicio'] ?? '')}  →  '
                            '${_formatFecha(a['fechaFin'] ?? '')}',
                            style:
                                textTheme.bodySmall?.copyWith(color: texto),
                          ),
                          if ((a['observaciones'] ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                a['observaciones'] as String,
                                style: textTheme.bodySmall?.copyWith(
                                    color: texto.withOpacity(0.75)),
                              ),
                            ),
                          if (a['obraNombre'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.business_outlined,
                                      size: 12,
                                      color: texto.withOpacity(0.8)),
                                  const SizedBox(width: 4),
                                  Text(
                                    a['obraNombre'] as String,
                                    style: textTheme.bodySmall?.copyWith(
                                        color: texto.withOpacity(0.8)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _labelTipo(String tipo) => switch (tipo) {
        'BAJA' => 'Baja médica',
        'VACACIONES' => 'Vacaciones',
        'PATERNIDAD' => 'Paternidad / Maternidad',
        _ => tipo,
      };
}
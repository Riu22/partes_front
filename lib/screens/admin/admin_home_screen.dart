import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/ausencia_info.dart';
import '../../providers/admin_provider.dart';
import '../../services/api_service.dart';

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

    return Scaffold(
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
                  final fechasSin = ausencias.values
                      .expand((a) => a.diasSin)
                      .toSet();
                  final fechasIncompletas = ausencias.values
                      .expand((a) => a.diasIncompletos.map((d) => d.fecha))
                      .toSet();
                  return _ResumenCard(
                    cargando: false,
                    totalPersonas: ausencias.length,
                    totalSin: fechasSin.length,
                    totalIncompletos: fechasIncompletas.length,
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Incidencias — histórico completo',
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
                      onRegistrarAusencia: (perfilId, nombre) async {
                        await showDialog(
                          context: context,
                          builder: (_) => _DialogoAusencia(
                            perfilId: perfilId,
                            nombre: nombre,
                            onGuardar: (tipo, inicio, fin, obs) async {
                              await ApiService().crearAusenciaLaboral(
                                perfilId: perfilId,
                                tipo: tipo,
                                fechaInicio: inicio,
                                fechaFin: fin,
                                observaciones: obs,
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
                            ausenciaExistente: ausencia,
                            onGuardar: (tipo, inicio, fin, obs) async {
                              await ApiService().eliminarAusenciaLaboral(
                                ausencia.id!,
                              );
                              await ApiService().crearAusenciaLaboral(
                                perfilId: perfilId,
                                tipo: tipo,
                                fechaInicio: inicio,
                                fechaFin: fin,
                                observaciones: obs,
                              );
                              ref.invalidate(diasSinParteProvider);
                            },
                          ),
                        );
                      },
                      onEliminarAusencia: (ausenciaId) async {
                        final confirmar = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar ausencia'),
                            content: const Text(
                              '¿Seguro que quieres eliminar esta ausencia?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (confirmar == true && context.mounted) {
                          try {
                            await ApiService().eliminarAusenciaLaboral(
                              ausenciaId,
                            );
                            ref.invalidate(diasSinParteProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al eliminar: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
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
    required this.onRegistrarAusencia,
    required this.onEditarAusencia,
    required this.onEliminarAusencia,
  });

  final AusenciaInfo ausencia;
  final String Function(String) formatFecha;
  final Future<void> Function(String perfilId, String fecha) onHabilitarFecha;
  final void Function(String perfilId, String nombre, String fecha)
  onCrearParte;
  final Future<void> Function(String perfilId, String nombre)
  onRegistrarAusencia;
  final Future<void> Function(
    AusenciaLaboral ausencia,
    String perfilId,
    String nombre,
  )
  onEditarAusencia;
  final Future<void> Function(int ausenciaId) onEliminarAusencia;

  @override
  State<_AusenciaCard> createState() => _AusenciaCardState();
}

class _AusenciaCardState extends State<_AusenciaCard> {
  String? _fechaActiva;
  int? _ausenciaActivaId;
  bool _habilitando = false;

  void _toggleFecha(String fecha) {
    setState(() {
      _fechaActiva = _fechaActiva == fecha ? null : fecha;
      _ausenciaActivaId = null;
    });
  }

  void _toggleAusencia(int id) {
    setState(() {
      _ausenciaActivaId = _ausenciaActivaId == id ? null : id;
      _fechaActiva = null;
    });
  }

  // ── Helpers de tipo de ausencia ──────────────────────────────────────────

  Color _colorFondoAusencia(String tipo, ColorScheme cs) {
    return switch (tipo) {
      'BAJA' => cs.errorContainer,
      'VACACIONES' => cs.secondaryContainer,
      'PATERNIDAD' => const Color(0xFFBFDBFE),
      _ => cs.surfaceVariant,
    };
  }

  Color _colorTextoAusencia(String tipo, ColorScheme cs) {
    return switch (tipo) {
      'BAJA' => cs.error,
      'VACACIONES' => cs.secondary,
      'PATERNIDAD' => const Color(0xFF1D4ED8),
      _ => cs.onSurfaceVariant,
    };
  }

  IconData _iconoAusencia(String tipo) {
    return switch (tipo) {
      'BAJA' => Icons.local_hospital_rounded,
      'VACACIONES' => Icons.beach_access_rounded,
      'PATERNIDAD' => Icons.child_friendly_rounded,
      _ => Icons.event_busy_rounded,
    };
  }

  String _labelAusencia(String tipo) {
    return switch (tipo) {
      'BAJA' => 'Baja',
      'VACACIONES' => 'Vacaciones',
      'PATERNIDAD' => 'Paternidad',
      _ => tipo,
    };
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
                IconButton(
                  tooltip: 'Registrar baja o vacaciones',
                  icon: Icon(
                    Icons.event_busy_rounded,
                    size: 20,
                    color: colorScheme.secondary,
                  ),
                  onPressed: () =>
                      widget.onRegistrarAusencia(ausencia.perfilId, nombre),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ausencia.soloAusencias
                        ? colorScheme.secondaryContainer
                        : colorScheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ausencia.soloAusencias
                        ? '${ausencia.ausenciasActivas.length} '
                              '${ausencia.ausenciasActivas.length == 1 ? 'ausencia' : 'ausencias'}'
                        : '${ausencia.totalIncidencias} '
                              '${ausencia.totalIncidencias == 1 ? 'incidencia' : 'incidencias'}',
                    style: textTheme.labelSmall?.copyWith(
                      color: ausencia.soloAusencias
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // ── Ausencias laborales activas ──
            if (ausencia.ausenciasActivas.isNotEmpty) ...[
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
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: expandida
                                ? colorScheme.inverseSurface
                                : _colorFondoAusencia(a.tipo, colorScheme),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _iconoAusencia(a.tipo),
                                size: 14,
                                color: expandida
                                    ? colorScheme.onInverseSurface
                                    : _colorTextoAusencia(a.tipo, colorScheme),
                              ),
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
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: IntrinsicWidth(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(
                                              () => _ausenciaActivaId = null,
                                            );
                                            widget.onEditarAusencia(
                                              a,
                                              ausencia.perfilId,
                                              nombre,
                                            );
                                          },
                                          borderRadius:
                                              const BorderRadius.vertical(
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
                                                Icon(
                                                  Icons.edit_rounded,
                                                  size: 15,
                                                  color: colorScheme.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Editar ausencia',
                                                  style: textTheme.labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            colorScheme.primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Divider(
                                          height: 1,
                                          color: colorScheme.outlineVariant,
                                        ),
                                        InkWell(
                                          onTap: () {
                                            setState(
                                              () => _ausenciaActivaId = null,
                                            );
                                            widget.onEliminarAusencia(a.id!);
                                          },
                                          borderRadius:
                                              const BorderRadius.vertical(
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
                                                  Icons.delete_rounded,
                                                  size: 15,
                                                  color: colorScheme.error,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Eliminar ausencia',
                                                  style: textTheme.labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            colorScheme.error,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                  ),
                );
              }),
            ],

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
// Diálogo registrar / editar ausencia
// ─────────────────────────────────────────────

class _DialogoAusencia extends StatefulWidget {
  const _DialogoAusencia({
    required this.perfilId,
    required this.nombre,
    required this.onGuardar,
    this.ausenciaExistente,
  });

  final String perfilId;
  final String nombre;
  final AusenciaLaboral? ausenciaExistente;
  final Future<void> Function(
    String tipo,
    DateTime inicio,
    DateTime fin,
    String? obs,
  )
  onGuardar;

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

  Future<void> _guardar() async {
    if (_inicio == null || _fin == null) {
      setState(() => _error = 'Selecciona las fechas de inicio y fin');
      return;
    }
    if (_fin!.isBefore(_inicio!)) {
      setState(() => _error = 'La fecha fin no puede ser anterior al inicio');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.onGuardar(
        _tipo,
        _inicio!,
        _fin!,
        _obsController.text.trim().isEmpty ? null : _obsController.text.trim(),
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
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TipoChip(
                  label: 'Baja',
                  icon: Icons.local_hospital_rounded,
                  seleccionado: _tipo == 'BAJA',
                  color: colorScheme.error,
                  onTap: () => setState(() => _tipo = 'BAJA'),
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
                  onTap: () => setState(() => _tipo = 'PATERNIDAD'),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
              Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
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
// Widgets reutilizables
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
          color: seleccionado ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: seleccionado ? color : Theme.of(context).dividerColor,
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            'Todos los operarios tienen parte\nen el histórico completo.',
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

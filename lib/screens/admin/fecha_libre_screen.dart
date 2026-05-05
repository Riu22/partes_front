import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/perfiles_provider.dart';
import '../../widgets/app_drawer.dart';

class FechaLibreScreen extends ConsumerStatefulWidget {
  const FechaLibreScreen({super.key});

  @override
  ConsumerState<FechaLibreScreen> createState() => _FechaLibreScreenState();
}

class _FechaLibreScreenState extends ConsumerState<FechaLibreScreen> {
  // Map<userId, List<DateTime>> con las fechas permitidas activas
  Map<String, List<DateTime>> _activos = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await ref.read(apiServiceProvider).getFechaLibreActivos();
      if (mounted) setState(() => _activos = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando permisos: $e')));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Abre un selector de fechas múltiples y añade las elegidas al usuario
  Future<void> _anadirFechas(String id, String nombre) async {
    final seleccionadas = await showDialog<List<DateTime>>(
      context: context,
      builder: (ctx) => _DialogSelectorFechas(
        titulo: 'Añadir fechas para $nombre',
        fechasYaPermitidas: _activos[id] ?? [],
      ),
    );
    if (seleccionadas == null || seleccionadas.isEmpty) return;

    try {
      await ref.read(apiServiceProvider).habilitarFechas(id, seleccionadas);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${seleccionadas.length} fecha(s) añadidas para $nombre',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Quita una fecha concreta de un usuario
  Future<void> _quitarFecha(String id, String nombre, DateTime fecha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar fecha'),
        content: Text(
          '¿Quitar el permiso del ${DateFormat('dd/MM/yyyy').format(fecha)} a $nombre?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(apiServiceProvider).deshabilitarFecha(id, fecha);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fecha ${DateFormat('dd/MM/yyyy').format(fecha)} eliminada para $nombre',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Quita todas las fechas de un usuario
  Future<void> _quitarTodas(String id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar todos los permisos'),
        content: Text('¿Quitar todas las fechas permitidas a $nombre?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar todas'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(apiServiceProvider).deshabilitarFechaLibre(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Todos los permisos eliminados para $nombre'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfilesAsync = ref.watch(perfilesProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Permisos de fecha libre'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : perfilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (perfiles) {
                final conPermiso = perfiles
                    .where(
                      (p) => p.activo && (_activos[p.id]?.isNotEmpty ?? false),
                    )
                    .toList();
                final sinPermiso = perfiles
                    .where(
                      (p) => p.activo && !(_activos[p.id]?.isNotEmpty ?? false),
                    )
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Banner informativo ──
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Puedes añadir días sueltos para que un operario pueda registrar partes fuera del límite de 2 semanas. '
                              'Los permisos se pierden si el servidor se reinicia.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Con fechas activas ──
                    if (conPermiso.isNotEmpty) ...[
                      _SectionHeader(
                        label: 'Con fechas permitidas (${conPermiso.length})',
                        color: Colors.green,
                        icon: Icons.lock_open,
                      ),
                      const SizedBox(height: 8),
                      ...conPermiso.map(
                        (p) => _CardPermisoFechas(
                          nombre: p.nombreCompleto,
                          fechas: _activos[p.id] ?? [],
                          onAnadir: () => _anadirFechas(p.id, p.nombreCompleto),
                          onQuitarFecha: (f) =>
                              _quitarFecha(p.id, p.nombreCompleto, f),
                          onQuitarTodas: () =>
                              _quitarTodas(p.id, p.nombreCompleto),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── Sin permisos ──
                    _SectionHeader(
                      label: 'Sin fechas permitidas (${sinPermiso.length})',
                      color: Colors.grey,
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 8),
                    if (sinPermiso.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Todos los usuarios tienen permisos activos',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...sinPermiso.map(
                        (p) => _CardSinPermiso(
                          nombre: p.nombreCompleto,
                          onAnadir: () => _anadirFechas(p.id, p.nombreCompleto),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

// ─── Card con permisos activos ────────────────────────────────────────────────
class _CardPermisoFechas extends StatefulWidget {
  final String nombre;
  final List<DateTime> fechas;
  final VoidCallback onAnadir;
  final Function(DateTime) onQuitarFecha;
  final VoidCallback onQuitarTodas;

  const _CardPermisoFechas({
    required this.nombre,
    required this.fechas,
    required this.onAnadir,
    required this.onQuitarFecha,
    required this.onQuitarTodas,
  });

  @override
  State<_CardPermisoFechas> createState() => _CardPermisoFechasState();
}

class _CardPermisoFechasState extends State<_CardPermisoFechas> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final fechasOrdenadas = [...widget.fechas]..sort();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: const Icon(Icons.person, color: Colors.green),
            ),
            title: Text(
              widget.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${widget.fechas.length} fecha(s) permitida(s)',
              style: TextStyle(color: Colors.green.shade700, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Expandir/colapsar las fechas
                IconButton(
                  icon: Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _expandido = !_expandido),
                ),
                // Añadir más fechas
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.green,
                  ),
                  tooltip: 'Añadir fechas',
                  onPressed: widget.onAnadir,
                ),
                // Quitar todas
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Quitar todas',
                  onPressed: widget.onQuitarTodas,
                ),
              ],
            ),
          ),
          // Lista de fechas individuales
          if (_expandido) ...[
            const Divider(height: 1),
            ...fechasOrdenadas.map(
              (f) => ListTile(
                dense: true,
                leading: const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.green,
                ),
                title: Text(
                  DateFormat('EEEE, dd/MM/yyyy', 'es').format(f),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  tooltip: 'Quitar esta fecha',
                  onPressed: () => widget.onQuitarFecha(f),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

// ─── Card sin permisos ────────────────────────────────────────────────────────
class _CardSinPermiso extends StatelessWidget {
  final String nombre;
  final VoidCallback onAnadir;

  const _CardSinPermiso({required this.nombre, required this.onAnadir});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade100,
          child: const Icon(Icons.person, color: Colors.grey),
        ),
        title: Text(
          nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Sin fechas permitidas',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
          tooltip: 'Añadir fechas',
          onPressed: onAnadir,
        ),
      ),
    );
  }
}

// ─── Dialog selector de fechas múltiples ─────────────────────────────────────
class _DialogSelectorFechas extends StatefulWidget {
  final String titulo;
  final List<DateTime> fechasYaPermitidas;

  const _DialogSelectorFechas({
    required this.titulo,
    required this.fechasYaPermitidas,
  });

  @override
  State<_DialogSelectorFechas> createState() => _DialogSelectorFechasState();
}

class _DialogSelectorFechasState extends State<_DialogSelectorFechas> {
  final List<DateTime> _seleccionadas = [];

  bool _yaPermitida(DateTime d) => widget.fechasYaPermitidas.any(
    (f) => f.year == d.year && f.month == d.month && f.day == d.day,
  );

  bool _estaSeleccionada(DateTime d) => _seleccionadas.any(
    (f) => f.year == d.year && f.month == d.month && f.day == d.day,
  );

  void _toggleFecha(DateTime d) {
    setState(() {
      if (_estaSeleccionada(d)) {
        _seleccionadas.removeWhere(
          (f) => f.year == d.year && f.month == d.month && f.day == d.day,
        );
      } else {
        _seleccionadas.add(d);
      }
    });
  }

  Future<void> _abrirDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(), // Usa hoy como base, es más seguro
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Selecciona una fecha para habilitar',
      // Quitamos la lógica que bloquea los días ya permitidos para evitar el crash
      selectableDayPredicate: null,
    );

    if (picked != null) {
      // La validación de si ya existe la haces después de elegirla, no en el calendario
      if (!_yaPermitida(picked)) {
        _toggleFecha(picked);
      } else {
        // Opcional: Mostrar un aviso de que ya está habilitada
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordenadas = [..._seleccionadas]..sort();

    return AlertDialog(
      title: Text(widget.titulo, style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón para añadir una fecha
            OutlinedButton.icon(
              onPressed: _abrirDatePicker,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir fecha'),
            ),
            const SizedBox(height: 12),

            // Lista de fechas seleccionadas
            if (_seleccionadas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Ninguna fecha seleccionada todavía.\nToca "Añadir fecha" para elegir.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )
            else ...[
              Text(
                '${_seleccionadas.length} fecha(s) a añadir:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  shrinkWrap: true,
                  children: ordenadas
                      .map(
                        (f) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.blue,
                          ),
                          title: Text(
                            DateFormat('dd/MM/yyyy').format(f),
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.red,
                            ),
                            onPressed: () => _toggleFecha(f),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _seleccionadas.isEmpty
              ? null
              : () => Navigator.pop(context, _seleccionadas),
          child: Text('Añadir ${_seleccionadas.length} fecha(s)'),
        ),
      ],
    );
  }
}

// ─── Cabecera de sección ──────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    );
  }
}

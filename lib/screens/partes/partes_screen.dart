import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/parte_trabajo.dart';
import '../../providers/sync_provider.dart';
import '../../providers/obras_provider.dart';
import '../../services/update_service.dart';

class PartesScreen extends ConsumerStatefulWidget {
  const PartesScreen({super.key});

  @override
  ConsumerState<PartesScreen> createState() => _PartesScreenState();
}

class _PartesScreenState extends ConsumerState<PartesScreen> {
  final _obraCtrl = TextEditingController();
  final _operarioCtrl = TextEditingController();
  String? _especialidadFiltro;
  bool _buscando = false;
  List<dynamic>? _resultadosBusqueda;
  final _updateService = UpdateService();

  bool get _hayFiltros =>
      _obraCtrl.text.isNotEmpty ||
      _operarioCtrl.text.isNotEmpty ||
      _especialidadFiltro != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Refresca obras del servidor cada vez que se entra a la pantalla (si hay red)
      final conectado = ref.read(conectividadProvider).valueOrNull ?? false;
      if (conectado) {
        ref.invalidate(obrasActivasProvider);
        ref.invalidate(obrasProvider);
      }
      if (!kIsWeb) _checkUpdate();
    });
  }

  Future<void> _checkUpdate() async {
    final update = await _updateService.hayActualizacion();
    if (update != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Nueva versión disponible'),
          content: Text(
            'Hay una actualización a la versión ${update['version']}.\n\n'
            'Descárgala para tener las últimas mejoras.\n\n'
            'Una vez descargado dale a abrir y selecciona actualizar.\n\n'
            'En caso de que de un error desinstale la aplicacion y vuelva a instalarla con el instalador que acaba de descargar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _updateService.abrirDescarga(update['url']!);
              },
              child: const Text('Descargar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _buscar() async {
    if (!_hayFiltros) {
      setState(() => _resultadosBusqueda = null);
      return;
    }
    setState(() => _buscando = true);
    try {
      final r = await ref
          .read(apiServiceProvider)
          .buscarPartes(
            obra: _obraCtrl.text,
            operario: _operarioCtrl.text,
            especialidad: _especialidadFiltro,
          );
      setState(() => _resultadosBusqueda = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _refrescar() async {
    ref.invalidate(partesProvider);
    ref.invalidate(partesJefeProvider);
    ref.invalidate(pendientesOfflineProvider);
    // NO invalidar obrasProvider para mantener cache offline
  }

  void _limpiarBusqueda() {
    _obraCtrl.clear();
    _operarioCtrl.clear();
    setState(() {
      _especialidadFiltro = null;
      _resultadosBusqueda = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncProvider);
    final pendientesAsync = ref.watch(pendientesOfflineProvider);
    final totalPendientes = pendientesAsync.valueOrNull ?? 0;
    final conexionAsync = ref.watch(conectividadProvider);
    final perfil = ref.watch(authProvider).valueOrNull;

    if (perfil == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Partes de Trabajo'),
        actions: [
          if (totalPendientes > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                tooltip: 'Sincronizar partes pendientes',
                onPressed: () {
                  ref.invalidate(syncProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Intentando enviar $totalPendientes parte(s)...',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: Badge(
                  label: Text('$totalPendientes'),
                  backgroundColor: Colors.orange,
                  child: const Icon(
                    Icons.cloud_off,
                    color: Colors.orange,
                    size: 28,
                  ),
                ),
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refrescar),
        ],
      ),
      body: Column(
        children: [
          if (!perfil.esOperario) _buildBuscador(),
          conexionAsync.when(
            data: (online) => online
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: Colors.red.shade100,
                    padding: const EdgeInsets.all(6),
                    child: const Text(
                      'Sin conexión — los partes se guardarán en el móvil',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            error: (_, __) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refrescar,
              child: _resultadosBusqueda != null
                  ? _ListaPartes(
                      partes: _resultadosBusqueda!
                          .map((p) => ParteTrabajo.fromJson(p))
                          .toList(),
                    )
                  : perfil.esJefeObra
                  ? const _PartesJefeView()
                  : const _PartesNormalesView(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_partes_unique',
        onPressed: () => context.go('/partes/nuevo'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBuscador() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: Colors.grey[50],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _obraCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Obra',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _operarioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Operario',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _especialidadFiltro,
                  decoration: const InputDecoration(
                    labelText: 'Especialidad',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todas')),
                    DropdownMenuItem(
                      value: 'ELECTRICIDAD',
                      child: Text('Electricidad'),
                    ),
                    DropdownMenuItem(
                      value: 'FONTANERIA',
                      child: Text('Fontanería'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _especialidadFiltro = v),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _buscando ? null : _buscar,
                icon: _buscando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Buscar'),
              ),
              if (_hayFiltros)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _limpiarBusqueda,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Lista unificada — misma card para todos
// ─────────────────────────────────────────
class _ListaPartes extends StatelessWidget {
  final List<ParteTrabajo> partes;
  const _ListaPartes({required this.partes});

  @override
  Widget build(BuildContext context) {
    if (partes.isEmpty) {
      return const Center(child: Text('No hay partes registrados'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8),
      itemCount: partes.length,
      itemBuilder: (context, index) => _CardParte(parte: partes[index]),
    );
  }
}

class _PartesNormalesView extends ConsumerWidget {
  const _PartesNormalesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesProvider);
    return partesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (partes) => _ListaPartes(partes: partes),
    );
  }
}

class _PartesJefeView extends ConsumerWidget {
  const _PartesJefeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesJefeProvider);
    return partesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (partes) {
        if (partes.isEmpty) {
          return const Center(child: Text('No hay partes registrados'));
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8),
          itemCount: partes.length,
          itemBuilder: (context, index) => _CardParteJefe(parte: partes[index]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
// Card unificada — ConsumerWidget para leer el rol
// ─────────────────────────────────────────
class _CardParte extends ConsumerWidget {
  final ParteTrabajo parte;
  const _CardParte({required this.parte});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;
    final esGestor = perfil?.esAdmin == true || perfil?.esGestion == true;

    // Gestores pueden editar cualquier parte; el resto solo los de hoy
    final puedeEditar = esGestor || parte.puedeEditarse;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(
          Icons.assignment,
          color: puedeEditar ? Colors.orange : Colors.grey,
          size: 30,
        ),
        title: Text(
          parte.obraNombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${parte.operarioNombre} • ${DateFormat('dd/MM/yyyy').format(parte.fecha)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${parte.horasNormales}h',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (parte.especialidad != null)
              _ChipEspecialidad(parte.especialidad!),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Descripción:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  parte.descripcion.isNotEmpty
                      ? parte.descripcion
                      : 'Sin descripción',
                ),
                const SizedBox(height: 15),
                if (puedeEditar)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.go('/partes/editar', extra: parte),
                      icon: const Icon(Icons.edit),
                      label: const Text('EDITAR PARTE'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Card específica para jefe de obra
// ─────────────────────────────────────────
class _CardParteJefe extends StatelessWidget {
  final dynamic parte;
  const _CardParteJefe({required this.parte});

  @override
  Widget build(BuildContext context) {
    final fechaStr = parte['fecha'] ?? '';
    final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();
    final obras = (parte['obras'] as List?) ?? [];
    final hoy = DateTime.now();
    final puedeEditar =
        fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
    final descripcion =
        (parte['descripcion'] != null &&
            parte['descripcion'].toString().isNotEmpty)
        ? parte['descripcion']
        : 'Sin descripción';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(
          Icons.assignment,
          color: puedeEditar ? Colors.orange : Colors.grey,
          size: 30,
        ),
        title: Text(
          DateFormat('dd/MM/yyyy').format(fecha),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${obras.length} obra(s)'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribución:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...obras.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.business,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(o['obra']?['nombre'] ?? '')),
                        Text(
                          '${o['porcentaje']}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (descripcion.isNotEmpty) ...[
                  const Divider(),
                  const Text(
                    'Descripción:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(descripcion),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Chip de especialidad
// ─────────────────────────────────────────
class _ChipEspecialidad extends StatelessWidget {
  final String especialidad;
  const _ChipEspecialidad(this.especialidad);

  @override
  Widget build(BuildContext context) {
    final esElectricidad = especialidad == 'ELECTRICIDAD';
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: esElectricidad ? Colors.amber[700] : Colors.blue[700],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        esElectricidad ? 'ELECT.' : 'FONT.',
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

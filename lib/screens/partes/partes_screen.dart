import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/parte_trabajo.dart';

class PartesScreen extends ConsumerWidget {
  const PartesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;
    if (perfil == null) return const SizedBox();

    if (perfil.esJefeObra) {
      return _PartesJefeScreen();
    }
    return _PartesNormalesScreen();
  }
}

// ─────────────────────────────────────────
// Partes para OPERARIO y ENCARGADO
// ─────────────────────────────────────────
class _PartesNormalesScreen extends ConsumerStatefulWidget {
  const _PartesNormalesScreen();

  @override
  ConsumerState<_PartesNormalesScreen> createState() =>
      _PartesNormalesScreenState();
}

class _PartesNormalesScreenState extends ConsumerState<_PartesNormalesScreen> {
  final _obraCtrl = TextEditingController();
  final _operarioCtrl = TextEditingController();
  String? _especialidadFiltro; // null = todos
  bool _buscando = false;
  List<dynamic>? _resultadosBusqueda;

  bool get _hayFiltros =>
      _obraCtrl.text.isNotEmpty ||
      _operarioCtrl.text.isNotEmpty ||
      _especialidadFiltro != null;

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
    } finally {
      setState(() => _buscando = false);
    }
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
    final partesAsync = ref.watch(partesProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final puedeValidar = perfil != null && !perfil.esOperario;
    final puedeVer = perfil != null && !perfil.esOperario;

    return Stack(
      children: [
        Column(
          children: [
            // Buscador — solo para roles que ven partes de otros
            if (puedeVer)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _obraCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Buscar por obra',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
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
                              labelText: 'Buscar por operario',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
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
                              DropdownMenuItem(
                                value: null,
                                child: Text('Todas'),
                              ),
                              DropdownMenuItem(
                                value: 'ELECTRICIDAD',
                                child: Text('Electricidad'),
                              ),
                              DropdownMenuItem(
                                value: 'FONTANERIA',
                                child: Text('Fontanería'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _especialidadFiltro = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _buscar,
                          icon: _buscando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                        if (_hayFiltros) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _limpiarBusqueda,
                            tooltip: 'Limpiar',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Lista de partes
            Expanded(
              child: _resultadosBusqueda != null
                  ? _listaDesdeJson(_resultadosBusqueda!, puedeValidar)
                  : partesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (partes) => partes.isEmpty
                          ? const Center(
                              child: Text('No hay partes registrados'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                left: 8,
                                right: 8,
                                top: 8,
                                bottom: 80,
                              ),
                              itemCount: partes.length,
                              itemBuilder: (context, index) {
                                final parte = partes[index];
                                return _CardParteNormal(
                                  parte: parte,
                                  puedeValidar: puedeValidar,
                                  onValidar: () =>
                                      _validarParte(context, ref, parte.id),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'fab_partes',
            onPressed: () => context.go('/partes/nuevo'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // Los resultados de búsqueda vienen como Map (dynamic) no como ParteTrabajo
  Widget _listaDesdeJson(List<dynamic> partes, bool puedeValidar) {
    if (partes.isEmpty) {
      return const Center(child: Text('Sin resultados'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 80),
      itemCount: partes.length,
      itemBuilder: (context, index) {
        final p = partes[index];
        final firmado = p['firmado'] ?? false;
        final fecha = DateTime.tryParse(p['fecha'] ?? '') ?? DateTime.now();
        final especialidad = p['especialidad'] ?? '';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Icon(
              firmado ? Icons.verified : Icons.pending_actions,
              color: firmado ? Colors.green : Colors.orange,
            ),
            title: Text(
              p['obra']?['nombre'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${p['perfil']?['name'] ?? ''} • ${DateFormat('dd/MM/yyyy').format(fecha)}',
            ),
            trailing: _chipEspecialidad(especialidad),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['descripcion_tareas'] ?? ''),
                    const SizedBox(height: 8),
                    Text(
                      'Horas: ${p['horas_normales'] ?? 8}h',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (!firmado && puedeValidar) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _validarParte(context, ref, p['id']),
                          icon: const Icon(Icons.edit_note),
                          label: const Text('FIRMAR PARTE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipEspecialidad(String especialidad) {
    final esElectricidad = especialidad == 'ELECTRICIDAD';
    return Chip(
      label: Text(
        esElectricidad ? 'Electricidad' : 'Fontanería',
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: esElectricidad ? Colors.amber[700] : Colors.blue[700],
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _validarParte(BuildContext context, WidgetRef ref, dynamic parteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Validar parte?'),
        content: const Text(
          'Al firmar confirmas que las horas y tareas son correctas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(apiServiceProvider).validarParte(parteId);
                ref.invalidate(partesProvider);
                setState(() => _resultadosBusqueda = null);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Partes para JEFE DE OBRA
// ─────────────────────────────────────────
class _PartesJefeScreen extends ConsumerWidget {
  const _PartesJefeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesJefeProvider);

    return Stack(
      children: [
        partesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (partes) => partes.isEmpty
              ? const Center(child: Text('No hay partes registrados'))
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                    top: 8,
                    bottom: 80,
                  ),
                  itemCount: partes.length,
                  itemBuilder: (context, index) {
                    final parte = partes[index];
                    return _CardParteJefe(parte: parte);
                  },
                ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'fab_partes_jefe',
            onPressed: () => context.go('/partes/nuevo'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Card parte normal
// ─────────────────────────────────────────
class _CardParteNormal extends StatelessWidget {
  final ParteTrabajo parte;
  final bool puedeValidar;
  final VoidCallback onValidar;

  const _CardParteNormal({
    required this.parte,
    required this.puedeValidar,
    required this.onValidar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(
          parte.firmado ? Icons.verified : Icons.pending_actions,
          color: parte.firmado ? Colors.green : Colors.orange,
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
            Text(
              parte.firmado ? 'FIRMADO' : 'PENDIENTE',
              style: TextStyle(
                fontSize: 10,
                color: parte.firmado ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                Text(parte.descripcion),
                const SizedBox(height: 15),
                if (!parte.firmado && puedeValidar)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onValidar,
                      icon: const Icon(Icons.edit_note),
                      label: const Text('FIRMAR PARTE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${parte.horasNormales}h',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          // Chip especialidad
          if (parte.especialidad != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: parte.especialidad == 'ELECTRICIDAD'
                    ? Colors.amber[700]
                    : Colors.blue[700],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                parte.especialidad == 'ELECTRICIDAD' ? 'Elect.' : 'Font.',
                style: const TextStyle(fontSize: 9, color: Colors.white),
              ),
            ),
          Text(
            parte.firmado ? 'FIRMADO' : 'PENDIENTE',
            style: TextStyle(
              fontSize: 10,
              color: parte.firmado ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Card parte jefe de obra
// ─────────────────────────────────────────
class _CardParteJefe extends StatelessWidget {
  final dynamic parte;
  const _CardParteJefe({required this.parte});

  @override
  Widget build(BuildContext context) {
    final bool firmado = parte['firmado'] ?? false;
    final fecha = DateTime.tryParse(parte['fecha'] ?? '') ?? DateTime.now();
    final obras = (parte['obras'] as List?) ?? [];

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(
          firmado ? Icons.verified : Icons.pending_actions,
          color: firmado ? Colors.green : Colors.orange,
          size: 30,
        ),
        title: Text(
          DateFormat('dd/MM/yyyy').format(fecha),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${obras.length} obra(s) • '
          '${firmado ? "FIRMADO" : "PENDIENTE"}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribución por obras:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ...obras.map(
                  (o) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Descripción:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 5),
                Text(parte['descripcion_tareas'] ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

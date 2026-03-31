import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/partes_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/parte_trabajo.dart';

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
      // Importante: asegúrate de tener este método en tu apiServiceProvider
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
        ).showSnackBar(SnackBar(content: Text('Error en búsqueda: $e')));
      }
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
    final perfil = ref.watch(authProvider).valueOrNull;
    if (perfil == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Column(
        children: [
          // Buscador superior
          _buildBuscador(perfil),
          Expanded(
            child: _resultadosBusqueda != null
                ? _listaDesdeJson(_resultadosBusqueda!, !perfil.esOperario)
                : (perfil.esJefeObra
                      ? const _PartesJefeView()
                      : _PartesNormalesView(perfil: perfil)),
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

  Widget _buildBuscador(dynamic perfil) {
    // Si es operario, quizás no quieres que busque partes de otros
    if (perfil.esOperario) return const SizedBox.shrink();

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
              if (_hayFiltros) ...[
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _limpiarBusqueda,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _listaDesdeJson(List<dynamic> partes, bool puedeValidar) {
    if (partes.isEmpty) return const Center(child: Text('Sin resultados'));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8),
      itemCount: partes.length,
      itemBuilder: (context, index) {
        final p = partes[index];
        return _CardGenericaBusqueda(p: p, puedeValidar: puedeValidar);
      },
    );
  }
}

// ─────────────────────────────────────────
// Vistas de Datos (Riverpod)
// ─────────────────────────────────────────

class _PartesNormalesView extends ConsumerWidget {
  final dynamic perfil;
  const _PartesNormalesView({required this.perfil});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partesAsync = ref.watch(partesProvider);
    final puedeValidar = !perfil.esOperario;

    return partesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (partes) => partes.isEmpty
          ? const Center(child: Text('No hay partes registrados'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8),
              itemCount: partes.length,
              itemBuilder: (context, index) => _CardParteNormal(
                parte: partes[index],
                puedeValidar: puedeValidar,
                onValidar: () =>
                    _validarParteGlobal(context, ref, partes[index].id),
              ),
            ),
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
      data: (partes) => partes.isEmpty
          ? const Center(child: Text('No hay partes registrados'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8),
              itemCount: partes.length,
              itemBuilder: (context, index) =>
                  _CardParteJefe(parte: partes[index]),
            ),
    );
  }
}

// ─────────────────────────────────────────
// Componentes de Tarjetas (Tus diseños originales)
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
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${parte.operarioNombre} • ${DateFormat('dd/MM/yyyy').format(parte.fecha)}',
            ),
            if (parte.especialidad != null)
              _chipEspecialidad(parte.especialidad!),
          ],
        ),
        trailing: _TrailingHoras(
          firmado: parte.firmado,
          horas: parte.horasNormales.toString(),
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
                Text(parte.descripcion),
                if (!parte.firmado && puedeValidar) ...[
                  const SizedBox(height: 15),
                  _BotonFirmar(onPressed: onValidar),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardParteJefe extends StatelessWidget {
  final dynamic parte;
  const _CardParteJefe({required this.parte});

  @override
  Widget build(BuildContext context) {
    final bool firmado = parte['firmado'] ?? false;
    final fechaStr = parte['fecha'] ?? '';
    final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();
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
          '${obras.length} obra(s) • ${firmado ? "FIRMADO" : "PENDIENTE"}',
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
                ...obras.map(
                  (o) => ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.business,
                      size: 16,
                      color: Colors.blue,
                    ),
                    title: Text(o['obra']?['nombre'] ?? ''),
                    trailing: Text(
                      '${o['porcentaje']}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Divider(),
                Text(parte['descripcion'] ?? 'SIN DESCRIPCION'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Card genérica para cuando los resultados vienen de la búsqueda (JSON)
class _CardGenericaBusqueda extends ConsumerWidget {
  final dynamic p;
  final bool puedeValidar;
  const _CardGenericaBusqueda({required this.p, required this.puedeValidar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firmado = p['firmado'] ?? false;
    final fechaStr = p['fecha'] ?? '';
    final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          firmado ? Icons.verified : Icons.pending_actions,
          color: firmado ? Colors.green : Colors.orange,
        ),
        title: Text(p['obra']?['nombre'] ?? 'Sin Obra'),
        subtitle: Text(
          '${p['perfil']?['name'] ?? ''} • ${DateFormat('dd/MM/yyyy').format(fecha)}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['descripcion'] ?? ''),
                if (!firmado && puedeValidar)
                  _BotonFirmar(
                    onPressed: () => _validarParteGlobal(context, ref, p['id']),
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
// Pequeños Widgets de apoyo para limpiar el código
// ─────────────────────────────────────────

Widget _chipEspecialidad(String especialidad) {
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

class _TrailingHoras extends StatelessWidget {
  final bool firmado;
  final String horas;
  const _TrailingHoras({required this.firmado, required this.horas});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$horas h',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          firmado ? 'FIRMADO' : 'PENDIENTE',
          style: TextStyle(
            fontSize: 9,
            color: firmado ? Colors.green : Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _BotonFirmar extends StatelessWidget {
  final VoidCallback onPressed;
  const _BotonFirmar({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.edit_note),
        label: const Text('FIRMAR PARTE'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

void _validarParteGlobal(BuildContext context, WidgetRef ref, dynamic parteId) {
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
              ref.invalidate(partesJefeProvider);
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

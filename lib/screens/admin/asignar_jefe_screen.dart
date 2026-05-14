import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/obra.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/obras_provider.dart';

class AsignarJefeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> usuario;
  final List<dynamic> todos;

  const AsignarJefeScreen({
    super.key,
    required this.usuario,
    required this.todos,
  });

  @override
  ConsumerState<AsignarJefeScreen> createState() => _AsignarJefeScreenState();
}

class _AsignarJefeScreenState extends ConsumerState<AsignarJefeScreen>
    with SingleTickerProviderStateMixin {
  // ── Estado pestaña Equipo ──
  String? _subordinadoSeleccionado;
  bool _enviando = false;
  bool _cargandoLista = true;
  List<dynamic> _subordinadosActuales = [];

  // ── Estado pestaña Obras ──
  String? _obraSeleccionada;
  bool _enviandoObra = false;
  bool _cargandoObras = true;
  List<dynamic> _obrasAsignadas = [];
  List<Obra> _todasLasObras = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarSubordinados();
    _cargarObrasAsignadas();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Leemos el provider de obras (ya cacheado, no hace otra llamada de red)
    final obrasAsync = ref.read(obrasProvider);
    obrasAsync.whenData((lista) {
      if (mounted) setState(() => _todasLasObras = lista);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Carga subordinados actuales de este jefe ──
  Future<void> _cargarSubordinados() async {
    setState(() => _cargandoLista = true);
    try {
      final api = ref.read(apiServiceProvider);
      final lista = await api.getSubordinadosDe(widget.usuario['id']);
      setState(() {
        _subordinadosActuales = lista;
        _cargandoLista = false;
      });
    } catch (e) {
      debugPrint('Error cargando subordinados: $e');
      setState(() => _cargandoLista = false);
    }
  }

  // ── Carga obras asignadas a este perfil ──
  Future<void> _cargarObrasAsignadas() async {
    setState(() => _cargandoObras = true);
    try {
      final api = ref.read(apiServiceProvider);
      // GET /api/v1/asignaciones/perfil/{perfilId}
      final lista = await api.getObrasDePerfil(widget.usuario['id']);
      setState(() {
        _obrasAsignadas = lista;
        _cargandoObras = false;
      });
    } catch (e) {
      debugPrint('Error cargando obras asignadas: $e');
      setState(() => _cargandoObras = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Filtro candidatos para subordinado ──
    final posiblesSubordinados = widget.todos.where((u) {
      final yaAsignado = _subordinadosActuales.any((s) => s['id'] == u['id']);
      final esElMismo = u['id'] == widget.usuario['id'];
      bool rolValido = false;
      if (widget.usuario['rol'] == 'JEFE_DE_OBRA') {
        rolValido = u['rol'] == 'ENCARGADO';
      } else if (widget.usuario['rol'] == 'ENCARGADO' ||
          widget.usuario['rol'] == 'GESTION') {
        rolValido = u['rol'] == 'OPERARIO';
      }
      return !yaAsignado && !esElMismo && rolValido;
    }).toList();

    // ── Filtro obras que aún no están asignadas a este perfil ──
    final obrasAsignadasIds = _obrasAsignadas
        .map((a) => a['obra']['id'].toString())
        .toSet();
    final posiblesObras = _todasLasObras
        .where((o) => !obrasAsignadasIds.contains(o.id.toString()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Equipo de ${widget.usuario['name']}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Equipo'),
            Tab(icon: Icon(Icons.business), text: 'Obras'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEquipoTab(posiblesSubordinados),
          _buildObrasTab(posiblesObras),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // PESTAÑA 1 — EQUIPO
  // ════════════════════════════════════════════
  Widget _buildEquipoTab(List<dynamic> posiblesSubordinados) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Asignar nuevo subordinado',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _subordinadoSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar personal',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_add),
                    ),
                    items: posiblesSubordinados.map((u) {
                      return DropdownMenuItem<String>(
                        value: u['id'] as String,
                        child: Text('${u['name']} (${u['rol']})'),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _subordinadoSeleccionado = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_subordinadoSeleccionado == null || _enviando)
                          ? null
                          : _confirmarAsignacion,
                      icon: _enviando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('AÑADIR AL EQUIPO'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subordinados actuales (${_subordinadosActuales.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_cargandoLista)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child: _subordinadosActuales.isEmpty && !_cargandoLista
              ? const Center(child: Text('No hay personal asignado todavía.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _subordinadosActuales.length,
                  itemBuilder: (context, index) {
                    final sub = _subordinadosActuales[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(sub['name'] ?? 'Sin nombre'),
                        subtitle: Text(sub['rol'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _confirmarEliminacion(sub),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // PESTAÑA 2 — OBRAS
  // ════════════════════════════════════════════
  Widget _buildObrasTab(List<Obra> posiblesObras) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Asignar a una obra',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _obraSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar obra',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                    items: posiblesObras.map((o) {
                      return DropdownMenuItem<String>(
                        value: o.id.toString(),
                        // ⚠️ Cambia 'o.nombre' por el campo real de tu modelo Obra
                        child: Text(o.nombre),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _obraSeleccionada = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_obraSeleccionada == null || _enviandoObra)
                          ? null
                          : _confirmarAsignacionObra,
                      icon: _enviandoObra
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('ASIGNAR A OBRA'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Obras asignadas (${_obrasAsignadas.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_cargandoObras)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child: _obrasAsignadas.isEmpty && !_cargandoObras
              ? const Center(child: Text('No hay obras asignadas todavía.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _obrasAsignadas.length,
                  itemBuilder: (context, index) {
                    final asignacion = _obrasAsignadas[index];
                    final obra = asignacion['obra'] as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.business),
                        ),
                        // ⚠️ Cambia 'nombre' por el campo real de tu JSON de obra
                        title: Text(obra['nombre'] ?? 'Obra ${obra['id']}'),
                        subtitle: Text('ID: ${obra['id']}'),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () =>
                              _confirmarEliminacionObra(asignacion),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════
  // LÓGICA — EQUIPO
  // ════════════════════════════════════════════

  Future<void> _confirmarAsignacion() async {
    setState(() => _enviando = true);
    try {
      final api = ref.read(apiServiceProvider);
      await api.asignarJefe(
        _subordinadoSeleccionado!,
        widget.usuario['id'],
        widget.usuario['rol'],
      );
      setState(() => _subordinadoSeleccionado = null);
      await _cargarSubordinados();
      ref.invalidate(usuariosProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asignación realizada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _confirmarEliminacion(Map<String, dynamic> subordinado) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar del equipo'),
        content: Text(
          '¿Deseas desvincular a ${subordinado['name']} de este jefe?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('QUITAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await ref.read(apiServiceProvider).quitarSubordinado(subordinado['id']);
        _cargarSubordinados();
        ref.invalidate(usuariosProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  // ════════════════════════════════════════════
  // LÓGICA — OBRAS
  // ════════════════════════════════════════════

  Future<void> _confirmarAsignacionObra() async {
    setState(() => _enviandoObra = true);
    try {
      final api = ref.read(apiServiceProvider);
      // POST /api/v1/asignaciones/asignar_a_obra/{perfilId}/{obraId}
      await api.asignarPerfilAObra(
        widget.usuario['id'] as String,
        int.parse(_obraSeleccionada!),
      );
      setState(() => _obraSeleccionada = null);
      await _cargarObrasAsignadas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Asignado a la obra con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviandoObra = false);
    }
  }

  Future<void> _confirmarEliminacionObra(
    Map<String, dynamic> asignacion,
  ) async {
    final obra = asignacion['obra'] as Map<String, dynamic>;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar de la obra'),
        content: Text(
          '¿Deseas desasignar a ${widget.usuario['name']} '
          'de "${obra['nombre'] ?? 'esta obra'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('QUITAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        // DELETE /api/v1/asignaciones/eliminar/{asignacionId}
        await ref
            .read(apiServiceProvider)
            .eliminarAsignacionObra(asignacion['id'] as int);
        _cargarObrasAsignadas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

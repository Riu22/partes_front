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
  bool _asignandoPersonal = false;
  bool _cargandoLista = true;
  List<dynamic> _subordinadosActuales = [];

  // Buscador y selección — Equipo
  final TextEditingController _busquedaPersonalCtrl = TextEditingController();
  String _filtroPersonal = '';
  final Set<String> _seleccionadosPersonal = {};

  // ── Estado pestaña Obras ──
  bool _asignandoObras = false;
  bool _cargandoObras = true;
  List<dynamic> _obrasAsignadas = [];
  List<Obra> _todasLasObras = [];

  // Buscador y selección — Obras
  final TextEditingController _busquedaObrasCtrl = TextEditingController();
  String _filtroObras = '';
  final Set<int> _seleccionadasObras = {};

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
    final obrasAsync = ref.read(obrasProvider);
    obrasAsync.whenData((lista) {
      if (mounted) setState(() => _todasLasObras = lista);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busquedaPersonalCtrl.dispose();
    _busquedaObrasCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _cargarObrasAsignadas() async {
    setState(() => _cargandoObras = true);
    try {
      final api = ref.read(apiServiceProvider);
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

  // ── Helpers — Personal ──

  List<dynamic> get _posiblesSubordinados {
    return widget.todos.where((u) {
      final yaAsignado =
          _subordinadosActuales.any((s) => s['id'] == u['id']);
      final esElMismo = u['id'] == widget.usuario['id'];
      bool rolValido = false;
      if (widget.usuario['rol'] == 'JEFE_DE_OBRA') {
        rolValido = u['rol'] == 'ENCARGADO' || u['rol'] == 'OPERARIO';
      } else if (widget.usuario['rol'] == 'ENCARGADO') {
        rolValido = u['rol'] == 'OPERARIO';
      } else if (widget.usuario['rol'] == 'GESTION') {
        rolValido = u['rol'] == 'OPERARIO';
      }
      return !yaAsignado && !esElMismo && rolValido;
    }).toList();
  }

  List<dynamic> get _personalFiltrado {
    if (_filtroPersonal.isEmpty) return _posiblesSubordinados;
    final q = _filtroPersonal.toLowerCase();
    return _posiblesSubordinados
        .where((u) =>
            (u['name'] as String).toLowerCase().contains(q) ||
            (u['rol'] as String).toLowerCase().contains(q))
        .toList();
  }

  bool get _todoPersonalFiltradoSeleccionado =>
      _personalFiltrado.isNotEmpty &&
      _personalFiltrado
          .every((u) => _seleccionadosPersonal.contains(u['id']));

  void _toggleSeleccionarTodoPersonal() {
    setState(() {
      if (_todoPersonalFiltradoSeleccionado) {
        for (final u in _personalFiltrado) {
          _seleccionadosPersonal.remove(u['id']);
        }
      } else {
        for (final u in _personalFiltrado) {
          _seleccionadosPersonal.add(u['id'] as String);
        }
      }
    });
  }

  // ── Helpers — Obras ──

  List<Obra> get _posiblesObras {
    final asignadasIds =
        _obrasAsignadas.map((a) => a['obra']['id'].toString()).toSet();
    return _todasLasObras
        .where((o) => !asignadasIds.contains(o.id.toString()))
        .toList();
  }

  List<Obra> get _obrasFiltradas {
    if (_filtroObras.isEmpty) return _posiblesObras;
    final q = _filtroObras.toLowerCase();
    return _posiblesObras
        .where((o) =>
            o.nombre.toLowerCase().contains(q) ||
            o.id.toString().contains(q))
        .toList();
  }

  bool get _todasObrasFiltadasSeleccionadas =>
      _obrasFiltradas.isNotEmpty &&
      _obrasFiltradas.every((o) => _seleccionadasObras.contains(o.id));

  void _toggleSeleccionarTodasObras() {
    setState(() {
      if (_todasObrasFiltadasSeleccionadas) {
        for (final o in _obrasFiltradas) {
          _seleccionadasObras.remove(o.id);
        }
      } else {
        for (final o in _obrasFiltradas) {
          _seleccionadasObras.add(o.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          _buildEquipoTab(),
          _buildObrasTab(),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // PESTAÑA 1 — EQUIPO
  // ════════════════════════════════════════════
  Widget _buildEquipoTab() {
    final filtrados = _personalFiltrado;
    final posibles = _posiblesSubordinados;

    return Column(
      children: [
        // ── Buscador + botón Todas ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busquedaPersonalCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar personal...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _filtroPersonal.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _busquedaPersonalCtrl.clear();
                              setState(() => _filtroPersonal = '');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filtroPersonal = v),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _todoPersonalFiltradoSeleccionado
                    ? 'Deseleccionar visibles'
                    : 'Seleccionar todos los visibles',
                child: OutlinedButton.icon(
                  onPressed: filtrados.isEmpty
                      ? null
                      : _toggleSeleccionarTodoPersonal,
                  icon: Icon(
                    _todoPersonalFiltradoSeleccionado
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    _todoPersonalFiltradoSeleccionado ? 'Ninguno' : 'Todos',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Barra de acción cuando hay selección ──
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _seleccionadosPersonal.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_seleccionadosPersonal.length} persona${_seleccionadosPersonal.length == 1 ? '' : 's'} seleccionada${_seleccionadosPersonal.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _seleccionadosPersonal.clear()),
                        child: const Text('Limpiar'),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: _asignandoPersonal
                            ? null
                            : _asignarPersonalSeleccionado,
                        icon: _asignandoPersonal
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.add, size: 16),
                        label: const Text('Asignar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // ── Contador ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _filtroPersonal.isEmpty
                    ? 'Personal disponible (${posibles.length})'
                    : '${filtrados.length} resultado${filtrados.length == 1 ? '' : 's'}',
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (_cargandoLista)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Lista con checkboxes — disponibles ──
        Expanded(
          child: filtrados.isEmpty && !_cargandoLista
              ? Center(
                  child: Text(_filtroPersonal.isEmpty
                      ? 'No hay personal disponible para asignar.'
                      : 'Sin resultados para "$_filtroPersonal"'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                      left: 8, right: 8, bottom: 80),
                  itemCount: filtrados.length,
                  itemBuilder: (context, index) {
                    final u = filtrados[index];
                    final marcado = _seleccionadosPersonal
                        .contains(u['id'] as String);
                    return CheckboxListTile(
                      value: marcado,
                      title: Text(u['name'] ?? 'Sin nombre'),
                      subtitle: Text(u['rol'] ?? '',
                          style: const TextStyle(fontSize: 12)),
                      secondary: CircleAvatar(
                        backgroundColor: marcado
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade200,
                        child: Icon(Icons.person,
                            size: 18,
                            color: marcado
                                ? Colors.white
                                : Colors.grey.shade600),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (v) => setState(() {
                        v == true
                            ? _seleccionadosPersonal.add(u['id'] as String)
                            : _seleccionadosPersonal
                                .remove(u['id'] as String);
                      }),
                    );
                  },
                ),
        ),

        // ── Subordinados actuales ──
        const Divider(height: 1),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subordinados actuales (${_subordinadosActuales.length})',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: _subordinadosActuales.isEmpty
              ? const Center(
                  child: Text('No hay personal asignado todavía.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _subordinadosActuales.length,
                  itemBuilder: (context, index) {
                    final sub = _subordinadosActuales[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                      title: Text(sub['name'] ?? 'Sin nombre',
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(sub['rol'] ?? '',
                          style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _confirmarEliminacion(sub),
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
  Widget _buildObrasTab() {
    final filtradas = _obrasFiltradas;
    final posibles = _posiblesObras;

    return Column(
      children: [
        // ── Buscador + botón Todas ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busquedaObrasCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar obra...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _filtroObras.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _busquedaObrasCtrl.clear();
                              setState(() => _filtroObras = '');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filtroObras = v),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _todasObrasFiltadasSeleccionadas
                    ? 'Deseleccionar visibles'
                    : 'Seleccionar todas las visibles',
                child: OutlinedButton.icon(
                  onPressed: filtradas.isEmpty
                      ? null
                      : _toggleSeleccionarTodasObras,
                  icon: Icon(
                    _todasObrasFiltadasSeleccionadas
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    _todasObrasFiltadasSeleccionadas ? 'Ninguna' : 'Todas',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Barra de acción cuando hay selección ──
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _seleccionadasObras.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_seleccionadasObras.length} obra${_seleccionadasObras.length == 1 ? '' : 's'} seleccionada${_seleccionadasObras.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _seleccionadasObras.clear()),
                        child: const Text('Limpiar'),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: _asignandoObras
                            ? null
                            : _asignarObrasSeleccionadas,
                        icon: _asignandoObras
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.add, size: 16),
                        label: const Text('Asignar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // ── Contador ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _filtroObras.isEmpty
                    ? 'Obras disponibles (${posibles.length})'
                    : '${filtradas.length} resultado${filtradas.length == 1 ? '' : 's'}',
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (_cargandoObras)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Lista con checkboxes — disponibles ──
        Expanded(
          child: filtradas.isEmpty && !_cargandoObras
              ? Center(
                  child: Text(_filtroObras.isEmpty
                      ? 'Todas las obras ya están asignadas.'
                      : 'Sin resultados para "$_filtroObras"'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                      left: 8, right: 8, bottom: 80),
                  itemCount: filtradas.length,
                  itemBuilder: (context, index) {
                    final obra = filtradas[index];
                    final marcada =
                        _seleccionadasObras.contains(obra.id);
                    return CheckboxListTile(
                      value: marcada,
                      title: Text(obra.nombre),
                      subtitle: Text('ID: ${obra.id}',
                          style: const TextStyle(fontSize: 12)),
                      secondary: CircleAvatar(
                        backgroundColor: marcada
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade200,
                        child: Icon(Icons.business,
                            size: 18,
                            color: marcada
                                ? Colors.white
                                : Colors.grey.shade600),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                      onChanged: (v) => setState(() {
                        v == true
                            ? _seleccionadasObras.add(obra.id)
                            : _seleccionadasObras.remove(obra.id);
                      }),
                    );
                  },
                ),
        ),

        // ── Obras ya asignadas ──
        const Divider(height: 1),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            'Obras asignadas (${_obrasAsignadas.length})',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 180,
          child: _obrasAsignadas.isEmpty
              ? const Center(
                  child: Text('No hay obras asignadas todavía.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _obrasAsignadas.length,
                  itemBuilder: (context, index) {
                    final asignacion = _obrasAsignadas[index];
                    final obra =
                        asignacion['obra'] as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                      title: Text(
                          obra['nombre'] ?? 'Obra ${obra['id']}',
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text('ID: ${obra['id']}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () =>
                            _confirmarEliminacionObra(asignacion),
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

  Future<void> _asignarPersonalSeleccionado() async {
    if (_seleccionadosPersonal.isEmpty) return;
    setState(() => _asignandoPersonal = true);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                  child: Text(
                      'Asignando ${_seleccionadosPersonal.length} personas...')),
            ],
          ),
        ),
      );
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.asignarSubordinadosBatch(
        widget.usuario['id'] as String,
        _seleccionadosPersonal.toList(),
      );
      final count = _seleccionadosPersonal.length;
      setState(() => _seleccionadosPersonal.clear());
      await _cargarSubordinados();
      ref.invalidate(usuariosProvider);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('$count personas asignadas correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _asignandoPersonal = false);
    }
  }

  Future<void> _confirmarEliminacion(Map<String, dynamic> subordinado) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar del equipo'),
        content: Text(
            '¿Deseas desvincular a ${subordinado['name']} de este jefe?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCELAR')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('QUITAR',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await ref
            .read(apiServiceProvider)
            .quitarSubordinado(subordinado['id']);
        _cargarSubordinados();
        ref.invalidate(usuariosProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  // ════════════════════════════════════════════
  // LÓGICA — OBRAS
  // ════════════════════════════════════════════

  Future<void> _asignarObrasSeleccionadas() async {
    if (_seleccionadasObras.isEmpty) return;
    setState(() => _asignandoObras = true);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                  child: Text(
                      'Asignando ${_seleccionadasObras.length} obras...')),
            ],
          ),
        ),
      );
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.asignarTodasLasObras(
        widget.usuario['id'] as String,
        _seleccionadasObras.toList(),
      );
      final count = _seleccionadasObras.length;
      setState(() => _seleccionadasObras.clear());
      await _cargarObrasAsignadas();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$count obras asignadas correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _asignandoObras = false);
    }
  }

  Future<void> _confirmarEliminacionObra(
      Map<String, dynamic> asignacion) async {
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
              child: const Text('CANCELAR')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('QUITAR',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await ref
            .read(apiServiceProvider)
            .eliminarAsignacionObra(asignacion['id'] as int);
        _cargarObrasAsignadas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
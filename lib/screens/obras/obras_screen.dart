// =============================================================================
// obras_screen.dart
// =============================================================================
// QUE ES:       Pantalla de gestion de obras.
// PARA QUE:     Administradores: crear, editar, asignar personal y eliminar
//               obras. Operarios/encargados: ver solo sus obras asignadas.
// QUIEN LO USA: Todos los roles, con diferentes niveles de acceso.
// COMO SE LLEGA: Desde el menu del panel de administracion o AppDrawer.
// A DONDE VA:   CRUD /api/obras, GET /api/asignaciones (servidor).
// QUE DATOS USA: admin_provider, auth_provider, obras_provider.
// OFFLINE:      No aplica.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/obras_provider.dart';

/// Punto de entrada para la pantalla de obras.
/// Redirige a la vista de admin o a la de operario segun el rol.
class ObrasScreen extends ConsumerWidget {
  const ObrasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final perfil = auth.valueOrNull;

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final esAdmin = perfil?.esAdmin ?? false;
    final esGestion = perfil?.esGestion ?? false;

    if (esAdmin || esGestion) {
      return _ObrasAdminView(esAdmin: esAdmin);
    } else {
      return const _MisObrasView();
    }
  }
}

// ============================================
// Vista admin - con buscador y CRUD completo
// ============================================
/// Vista de administracion de obras: lista todas las obras con filtros
/// por nombre, municipio y estado. Permite crear, editar, asignar
/// personal y eliminar obras.
class _ObrasAdminView extends ConsumerStatefulWidget {
  final bool esAdmin;
  const _ObrasAdminView({required this.esAdmin});

  @override
  ConsumerState<_ObrasAdminView> createState() => _ObrasAdminViewState();
}

class _ObrasAdminViewState extends ConsumerState<_ObrasAdminView> {
  // -- Controladores para filtros --
  final _nombreCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  bool? _activaFiltro; // null = todas, true = activas, false = inactivas

  /// Verifica si hay algun filtro activo.
  bool get _hayFiltros =>
      _nombreCtrl.text.isNotEmpty ||
      _municipioCtrl.text.isNotEmpty ||
      _activaFiltro != null;

  /// Filtra la lista de obras segun los criterios activos.
  List<dynamic> _filtrar(List<dynamic> obras) {
    return obras.where((o) {
      final nombre = o.nombre.toString().toLowerCase();
      final municipio = o.municipio.toString().toLowerCase();
      final matchNombre =
          _nombreCtrl.text.isEmpty ||
          nombre.contains(_nombreCtrl.text.toLowerCase());
      final matchMunicipio =
          _municipioCtrl.text.isEmpty ||
          municipio.contains(_municipioCtrl.text.toLowerCase());
      final matchActiva = _activaFiltro == null || o.activa == _activaFiltro;
      return matchNombre && matchMunicipio && matchActiva;
    }).toList();
  }

  /// Limpia todos los filtros de busqueda.
  void _limpiarBusqueda() {
    _nombreCtrl.clear();
    _municipioCtrl.clear();
    setState(() => _activaFiltro = null);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _municipioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Obras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(obrasProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_crear_obra_admin',
        onPressed: () => _mostrarDialogoCrear(context, ref),
        child: const Icon(Icons.add_business),
      ),
      body: Column(
        children: [
          _buildBuscador(),
          Expanded(
            child: obrasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (obras) {
                final filtradas = _filtrar(obras);
                if (filtradas.isEmpty) {
                  return const Center(
                    child: Text('No hay obras que coincidan'),
                  );
                }
                // Lista de obras con ExpansionTile
                return ListView.builder(
                  itemCount: filtradas.length,
                  padding: const EdgeInsets.only(
                    bottom: 80,
                    top: 8,
                    left: 8,
                    right: 8,
                  ),
                  itemBuilder: (context, index) {
                    final o = filtradas[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ExpansionTile(
                        leading: Icon(
                          Icons.business,
                          color: o.activa ? Colors.blue : Colors.grey,
                        ),
                        title: Text(
                          o.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${o.municipio} - ${o.ubicacion}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (accion) {
                            if (accion == 'editar') {
                              _mostrarDialogoEditar(context, ref, o);
                            }
                            if (accion == 'asignar') {
                              _mostrarDialogoAsignar(context, ref, o.id);
                            }
                            if (accion == 'eliminar') {
                              _confirmarEliminar(context, ref, o.id);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            const PopupMenuItem(
                              value: 'asignar',
                              child: Text('Asignar persona'),
                            ),
                            if (widget.esAdmin)
                              const PopupMenuItem(
                                value: 'eliminar',
                                child: Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                        // Muestra las personas asignadas a esta obra
                        children: [_AsignacionesObraWidget(obraId: o.id)],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la barra de filtros de busqueda.
  Widget _buildBuscador() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: Colors.grey[50],
      child: Column(
        children: [
          // Filtro por nombre
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de obra',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 8),
          // Filtro por estado (activa/inactiva)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<bool?>(
                  value: _activaFiltro,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todas')),
                    DropdownMenuItem(value: true, child: Text('Activas')),
                    DropdownMenuItem(value: false, child: Text('Inactivas')),
                  ],
                  onChanged: (v) => setState(() => _activaFiltro = v),
                ),
              ),
              if (_hayFiltros) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Limpiar filtros',
                  onPressed: _limpiarBusqueda,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---- Dialogs de CRUD ----

  /// Dialogo para crear una nueva obra.
  void _mostrarDialogoCrear(BuildContext context, WidgetRef ref) {
    final nombreCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final municipioCtrl = TextEditingController();
    final poblacionCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva obra'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nombreCtrl, 'Nombre'),
              const SizedBox(height: 12),
              _buildTextField(direccionCtrl, 'Direccion'),
              const SizedBox(height: 12),
              _buildTextField(municipioCtrl, 'Municipio'),
              const SizedBox(height: 12),
              _buildTextField(poblacionCtrl, 'Poblacion'),
              const SizedBox(height: 12),
              _buildTextField(codigoCtrl, 'Codigo'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(apiServiceProvider).crearObra({
                  'nombre': nombreCtrl.text.trim(),
                  'direccion': direccionCtrl.text.trim(),
                  'municipio': municipioCtrl.text.trim(),
                  'poblacion': poblacionCtrl.text.trim(),
                  'codigo': codigoCtrl.text.trim(),
                });
                ref.invalidate(obrasProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                _mostrarError(context, e.toString());
              }
            },
            child: const Text('CREAR'),
          ),
        ],
      ),
    );
  }

  /// Dialogo para editar una obra existente.
  void _mostrarDialogoEditar(
    BuildContext context,
    WidgetRef ref,
    dynamic obra,
  ) {
    final nombreCtrl = TextEditingController(text: obra.nombre);
    final direccionCtrl = TextEditingController(text: obra.ubicacion);
    final municipioCtrl = TextEditingController(text: obra.municipio);
    bool activa = obra.activa;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar obra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(nombreCtrl, 'Nombre'),
              const SizedBox(height: 12),
              _buildTextField(direccionCtrl, 'Direccion'),
              const SizedBox(height: 12),
              _buildTextField(municipioCtrl, 'Municipio'),
              const SizedBox(height: 12),
              // Switch para activar/desactivar obra
              SwitchListTile(
                title: const Text('Obra activa'),
                subtitle: Text(activa ? 'Activa' : 'Inactiva'),
                value: activa,
                onChanged: (v) => setState(() => activa = v),
                activeColor: Colors.green,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(apiServiceProvider).editarObra(obra.id, {
                    'nombre': nombreCtrl.text.trim(),
                    'direccion': direccionCtrl.text.trim(),
                    'municipio': municipioCtrl.text.trim(),
                    'activa': activa,
                  });
                  ref.invalidate(obrasProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  _mostrarError(context, e.toString());
                }
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialogo para asignar una persona (jefe/encargado) a una obra.
  void _mostrarDialogoAsignar(BuildContext context, WidgetRef ref, int obraId) {
    final usuariosAsync = ref.read(usuariosProvider);
    String? perfilSeleccionado;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Asignar a obra'),
          content: usuariosAsync.when(
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error al cargar usuarios: $e'),
            data: (usuarios) {
              // Filtra solo jefes de obra y encargados
              final elegibles = usuarios
                  .where(
                    (u) => ['JEFE_DE_OBRA', 'ENCARGADO'].contains(u['rol']),
                  )
                  .toList();
              return DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Persona',
                  border: OutlineInputBorder(),
                ),
                items: elegibles
                    .map(
                      (u) => DropdownMenuItem(
                        value: u['id'].toString(),
                        child: Text('${u['name']} (${u['rol']})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => perfilSeleccionado = v),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: perfilSeleccionado == null
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(apiServiceProvider)
                            .asignarAObra(perfilSeleccionado!, obraId);
                        ref.invalidate(asignacionesObraProvider(obraId));
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        _mostrarError(context, e.toString());
                      }
                    },
              child: const Text('ASIGNAR'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialogo de confirmacion para eliminar una obra.
  void _confirmarEliminar(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar obra?'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await ref.read(apiServiceProvider).eliminarObra(id);
                ref.invalidate(obrasProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                _mostrarError(context, e.toString());
              }
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  /// Construye un TextField generico para los dialogs.
  Widget _buildTextField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  /// Muestra un mensaje de error en SnackBar.
  void _mostrarError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ============================================
// Vista operario/encargado
// ============================================
/// Vista para operarios/encargados: muestra solo las obras que tiene
/// asignadas el usuario actual.
class _MisObrasView extends ConsumerWidget {
  const _MisObrasView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final misObrasAsync = ref.watch(misAsignacionesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Obras Asignadas')),
      body: misObrasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (asignaciones) => asignaciones.isEmpty
            ? const Center(
                child: Text(
                  'No tienes obras asignadas',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: asignaciones.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final a = asignaciones[index] as Map<String, dynamic>;
                  final obra = a['obra'] as Map<String, dynamic>?;
                  if (obra == null) return const SizedBox();
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.business, color: Colors.blue),
                      title: Text(
                        obra['nombre'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${obra['municipio'] ?? ''} - ${obra['ubicacion'] ?? ''}',
                      ),
                      trailing: Chip(
                        label: Text(
                          (obra['activa'] ?? true) ? 'ACTIVA' : 'INACTIVA',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: (obra['activa'] ?? true)
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ============================================
// Widget de asignaciones por obra
// ============================================
/// Widget que muestra las personas asignadas a una obra dentro del
/// ExpansionTile, con opcion para desasignarlas.
class _AsignacionesObraWidget extends ConsumerWidget {
  final int obraId;
  const _AsignacionesObraWidget({required this.obraId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asignacionesAsync = ref.watch(asignacionesObraProvider(obraId));

    return asignacionesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) =>
          Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e')),
      data: (asignaciones) => asignaciones.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sin personas asignadas',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: asignaciones.map<Widget>((a) {
                final nombre = a['perfil']?['name'] ?? 'Sin nombre';
                final rol = a['perfil']?['rol'] ?? '';
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.person, size: 20),
                  title: Text(nombre),
                  subtitle: Text(rol),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () async {
                      try {
                        await ref
                            .read(apiServiceProvider)
                            .eliminarAsignacionObra(a['id']);
                        ref.invalidate(asignacionesObraProvider(obraId));
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                  ),
                );
              }).toList(),
            ),
    );
  }
}

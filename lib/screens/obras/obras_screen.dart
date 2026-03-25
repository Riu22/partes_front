import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/partes_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

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

class _ObrasAdminView extends ConsumerWidget {
  final bool esAdmin;
  const _ObrasAdminView({required this.esAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: obrasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (obras) => obras.isEmpty
            ? const Center(child: Text('No hay obras registradas'))
            : ListView.builder(
                itemCount: obras.length,
                padding: const EdgeInsets.only(
                  bottom: 80,
                  top: 8,
                  left: 8,
                  right: 8,
                ),
                itemBuilder: (context, index) {
                  final o = obras[index];
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
                      subtitle: Text('${o.municipio} • ${o.ubicacion}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (accion) {
                          if (accion == 'editar')
                            _mostrarDialogoEditar(context, ref, o);
                          if (accion == 'asignar')
                            _mostrarDialogoAsignar(context, ref, o.id);
                          if (accion == 'eliminar')
                            _confirmarEliminar(context, ref, o.id);
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
                          if (esAdmin)
                            const PopupMenuItem(
                              value: 'eliminar',
                              child: Text(
                                'Eliminar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                      children: [_AsignacionesObraWidget(obraId: o.id)],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _mostrarDialogoCrear(BuildContext context, WidgetRef ref) {
    final nombreCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final municipioCtrl = TextEditingController();
    final poblacionCtrl = TextEditingController();

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
              _buildTextField(direccionCtrl, 'Dirección'),
              const SizedBox(height: 12),
              _buildTextField(municipioCtrl, 'Municipio'),
              const SizedBox(height: 12),
              _buildTextField(poblacionCtrl, 'Población'),
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
                });
                ref.invalidate(obrasProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                _mostrarError(context, e);
              }
            },
            child: const Text('CREAR'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditar(
    BuildContext context,
    WidgetRef ref,
    dynamic obra,
  ) {
    final nombreCtrl = TextEditingController(text: obra.nombre);
    final direccionCtrl = TextEditingController(text: obra.ubicacion);
    final municipioCtrl = TextEditingController(text: obra.municipio);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar obra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(nombreCtrl, 'Nombre'),
            const SizedBox(height: 12),
            _buildTextField(direccionCtrl, 'Dirección'),
            const SizedBox(height: 12),
            _buildTextField(municipioCtrl, 'Municipio'),
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
                });
                ref.invalidate(obrasProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                _mostrarError(context, e);
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

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
                        _mostrarError(context, e);
                      }
                    },
              child: const Text('ASIGNAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar obra?'),
        content: const Text('Esta acción no se puede deshacer.'),
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
                _mostrarError(context, e);
              }
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  void _mostrarError(BuildContext context, Object e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error: $e')));
  }
}

class _MisObrasView extends ConsumerWidget {
  const _MisObrasView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final misObrasAsync = ref.watch(misObrasProvider);

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
                  final a = asignaciones[index];
                  final obra = a['obra'];
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
                        '${obra['municipio'] ?? ''} • ${obra['ubicacion'] ?? ''}',
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

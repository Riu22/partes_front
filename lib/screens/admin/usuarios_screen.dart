import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

class UsuariosScreen extends ConsumerWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(usuariosProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final esAdmin = perfil?.esAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(usuariosProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarDialogoCrear(context, ref),
        child: const Icon(Icons.person_add),
      ),
      body: usuariosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (usuarios) => ListView.builder(
          itemCount: usuarios.length,
          padding: const EdgeInsets.all(8),
          itemBuilder: (context, index) {
            final u = usuarios[index];
            final bool activo = u['activo'] ?? true;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _colorRol(u['rol']),
                  child: Text(
                    (u['name'] ?? u['email'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(u['name'] ?? 'Sin nombre'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['email'] ?? ''),
                    Row(
                      children: [
                        _chipRol(u['rol']),
                        const SizedBox(width: 8),
                        _chipActivo(activo),
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'editar', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'jefe',
                      child: Text('Asignar jefe'),
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
                  onSelected: (accion) {
                    if (accion == 'editar') {
                      _mostrarDialogoEditar(context, ref, u);
                    } else if (accion == 'jefe') {
                      _mostrarDialogoAsignarJefe(context, ref, u, usuarios);
                    } else if (accion == 'eliminar') {
                      _confirmarEliminar(context, ref, u['id']);
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _colorRol(String? rol) {
    switch (rol) {
      case 'ADMINISTRACION':
        return Colors.purple;
      case 'GESTION':
        return Colors.blue;
      case 'JEFE_DE_OBRA':
        return Colors.teal;
      case 'ENCARGADO':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _chipRol(String? rol) => Chip(
    label: Text(
      rol ?? 'OPERARIO',
      style: const TextStyle(fontSize: 10, color: Colors.white),
    ),
    backgroundColor: _colorRol(rol),
    padding: EdgeInsets.zero,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _chipActivo(bool activo) => Chip(
    label: Text(
      activo ? 'ACTIVO' : 'INACTIVO',
      style: const TextStyle(fontSize: 10, color: Colors.white),
    ),
    backgroundColor: activo ? Colors.green : Colors.red,
    padding: EdgeInsets.zero,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  void _mostrarDialogoCrear(BuildContext context, WidgetRef ref) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String rolSeleccionado = 'OPERARIO';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Crear usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: rolSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'OPERARIO',
                            'ENCARGADO',
                            'JEFE_DE_OBRA',
                            'GESTION',
                            'ADMINISTRACION',
                          ]
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => rolSeleccionado = v!),
                ),
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
                Navigator.pop(context);
                try {
                  await ref.read(apiServiceProvider).crearUsuario({
                    'email': emailCtrl.text.trim(),
                    'password': passCtrl.text.trim(),
                    'name': nameCtrl.text.trim(),
                    'rol': rolSeleccionado,
                  });
                  ref.invalidate(usuariosProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('CREAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoEditar(BuildContext context, WidgetRef ref, Map u) {
    final nameCtrl = TextEditingController(text: u['name'] ?? '');
    String rolSeleccionado = u['rol'] ?? 'OPERARIO';
    bool activo = u['activo'] ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: rolSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'OPERARIO',
                            'ENCARGADO',
                            'JEFE_DE_OBRA',
                            'GESTION',
                            'ADMINISTRACION',
                          ]
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => rolSeleccionado = v!),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Activo'),
                  value: activo,
                  onChanged: (v) => setState(() => activo = v),
                ),
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
                Navigator.pop(context);
                try {
                  await ref.read(apiServiceProvider).editarUsuario(u['id'], {
                    'name': nameCtrl.text.trim(),
                    'rol': rolSeleccionado,
                    'activo': activo,
                  });
                  ref.invalidate(usuariosProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoAsignarJefe(
    BuildContext context,
    WidgetRef ref,
    Map usuario,
    List usuarios,
  ) {
    String? jefeSeleccionado;
    final posiblesJefes = usuarios
        .where(
          (u) =>
              u['id'] != usuario['id'] &&
              [
                'ENCARGADO',
                'JEFE_DE_OBRA',
                'GESTION',
                'ADMINISTRACION',
              ].contains(u['rol']),
        )
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Asignar jefe a ${usuario['name']}'),
          content: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Jefe directo',
              border: OutlineInputBorder(),
            ),
            items: posiblesJefes
                .map(
                  (u) => DropdownMenuItem<String>(
                    value: u['id'],
                    child: Text('${u['name']} (${u['rol']})'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => jefeSeleccionado = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: jefeSeleccionado == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      try {
                        await ref
                            .read(apiServiceProvider)
                            .asignarJefe(usuario['id'], jefeSeleccionado!);
                        ref.invalidate(usuariosProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              child: const Text('ASIGNAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar usuario?'),
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
              Navigator.pop(context);
              try {
                await ref.read(apiServiceProvider).eliminarUsuario(id);
                ref.invalidate(usuariosProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }
}

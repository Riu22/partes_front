import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/buscador_operario.dart';

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(usuariosProvider);
    final perfil = ref.watch(authProvider).valueOrNull;
    final esAdmin = perfil?.esAdmin ?? false;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/usuarios/nuevo'),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          // INTEGRACIÓN DEL BUSCADOR
          BuscadorOperario(
            onBuscar: (texto) => setState(() => _filtro = texto),
            onLimpiar: () => setState(() => _filtro = ''),
          ),

          Expanded(
            child: usuariosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (usuarios) {
                // FILTRADO LOCAL
                final listaFiltrada = usuarios.where((u) {
                  final nombre = (u['name'] ?? '').toString().toLowerCase();
                  final email = (u['email'] ?? '').toString().toLowerCase();
                  return nombre.contains(_filtro.toLowerCase()) ||
                      email.contains(_filtro.toLowerCase());
                }).toList();

                if (listaFiltrada.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron usuarios'),
                  );
                }

                return ListView.builder(
                  itemCount: listaFiltrada.length,
                  padding: const EdgeInsets.only(bottom: 80, top: 10),
                  itemBuilder: (context, index) {
                    final u = listaFiltrada[index];
                    return _buildUsuarioCard(
                      context,
                      ref,
                      u,
                      esAdmin,
                      usuarios,
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

  Widget _buildUsuarioCard(
    BuildContext context,
    WidgetRef ref,
    dynamic u,
    bool esAdmin,
    List<dynamic> todos,
  ) {
    final bool activo = u['activo'] ?? true;
    final jefe = u['jefeDirecto'];
    final String rol = u['rol'] ?? 'OPERARIO';

    // Determinamos si este usuario puede tener subordinados para cambiar el texto del menú
    final bool puedeTenerEquipo = [
      'JEFE_DE_OBRA',
      'ENCARGADO',
      'GESTION',
      'ADMINISTRACION',
    ].contains(rol);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _colorRol(rol),
          child: Text(
            (u['name'] ?? u['email'] ?? '?')[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          u['name'] ?? 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                u['email'] ?? '',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              if (jefe != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Jefe: ${jefe['name']}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [_chipRol(rol), _chipActivo(activo)]),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          onSelected: (accion) {
            if (accion == 'editar') context.go('/usuarios/editar', extra: u);
            if (accion == 'equipo') {
              context.go(
                '/usuarios/asignar-jefe',
                extra: {'usuario': u, 'todos': todos},
              );
            }
            if (accion == 'eliminar') _confirmarEliminar(context, ref, u['id']);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'editar',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
            if (puedeTenerEquipo)
              const PopupMenuItem(
                value: 'equipo',
                child: Row(
                  children: [
                    Icon(Icons.groups, size: 20),
                    SizedBox(width: 8),
                    Text('Gestionar Equipo'),
                  ],
                ),
              ),
            if (esAdmin)
              const PopupMenuItem(
                value: 'eliminar',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
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
        return Colors.blueGrey;
    }
  }

  Widget _chipRol(String rol) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: _colorRol(rol),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      rol,
      style: const TextStyle(
        fontSize: 9,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _chipActivo(bool activo) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: activo ? Colors.green : Colors.red,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      activo ? 'ACTIVO' : 'INACTIVO',
      style: const TextStyle(
        fontSize: 9,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  void _confirmarEliminar(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar usuario?'),
        content: const Text(
          'Esta acción no se puede deshacer y afectará a las asignaciones actuales.',
        ),
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

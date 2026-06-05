// =============================================================================
// usuarios_screen.dart
// =============================================================================
// QUE ES:       Pantalla de listado de usuarios del sistema.
// PARA QUE:     Mostrar todos los perfiles con rol, email, jefe y estado.
//               Permite buscar, editar, gestionar equipo y eliminar usuarios.
// QUIEN LO USA: Administradores y gestion.
// COMO SE LLEGA: Desde el panel admin, ruta /usuarios.
// A DONDE VA:   GET /api/usuarios, DELETE /api/usuarios (servidor).
// QUE DATOS USA: admin_provider, auth_provider, buscador_operario widget.
// OFFLINE:      No aplica.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/buscador_operario.dart';

/// Lista todos los usuarios del sistema con opciones de busqueda,
/// edicion, gestion de equipo y eliminacion.
class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

/// Estado del listado de usuarios: gestiona filtro de busqueda,
/// carga de usuarios y construccion de la UI.
class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  String _filtro = '';         // Texto para filtrar usuarios
  bool? _activoFiltro;         // null = todos, true = activos, false = inactivos

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
          // Barra de busqueda por texto
          BuscadorOperario(
            onBuscar: (texto) => setState(() => _filtro = texto),
            onLimpiar: () => setState(() {
              _filtro = '';
              _activoFiltro = null;
            }),
          ),
          // Filtro de estado activo/inactivo
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<bool?>(
                    value: _activoFiltro,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null,  child: Text('Todos')),
                      DropdownMenuItem(value: true,  child: Text('Activos')),
                      DropdownMenuItem(value: false, child: Text('Inactivos')),
                    ],
                    onChanged: (v) => setState(() => _activoFiltro = v),
                  ),
                ),
                if (_activoFiltro != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Limpiar filtro de estado',
                    onPressed: () => setState(() => _activoFiltro = null),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: usuariosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (usuarios) {
                // Filtra por texto (nombre, apellidos, email) y por estado
                final listaFiltrada = usuarios.where((u) {
                  final nombre = (u['name'] ?? '').toString().toLowerCase();
                  final apellidos =
                      (u['apellidos'] ?? '').toString().toLowerCase();
                  final email = (u['email'] ?? '').toString().toLowerCase();
                  final filtroLower = _filtro.toLowerCase();
                  final matchTexto = nombre.contains(filtroLower) ||
                      apellidos.contains(filtroLower) ||
                      email.contains(filtroLower);
                  // Trata null como activo (igual que _chipActivo)
                  final matchActivo = _activoFiltro == null ||
                      (u['activo'] ?? true) == _activoFiltro;
                  return matchTexto && matchActivo;
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

  /// Construye el nombre completo a partir de apellidos + nombre.
  String _nombreCompleto(dynamic u) {
    final apellidos = (u['apellidos'] ?? '').toString().trim();
    final nombre = (u['name'] ?? '').toString().trim();
    final completo = '$apellidos $nombre'.trim();
    return completo.isEmpty ? 'Sin nombre' : completo;
  }

  /// Obtiene la inicial del usuario para el avatar.
  String _inicial(dynamic u) {
    final apellidos = (u['apellidos'] ?? '').toString().trim();
    if (apellidos.isNotEmpty) return apellidos[0].toUpperCase();
    final nombre = (u['name'] ?? '').toString().trim();
    if (nombre.isNotEmpty) return nombre[0].toUpperCase();
    final email = (u['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  /// Construye una tarjeta de usuario con acciones disponibles.
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

    // Roles que pueden tener equipo a su cargo
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
            _inicial(u),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          _nombreCompleto(u),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email
              Text(
                u['email'] ?? '',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              // Jefe directo (si tiene)
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
                    'Jefe: ${_nombreCompleto(jefe)}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // Chips de rol y estado
              Wrap(spacing: 6, children: [_chipRol(rol), _chipActivo(activo)]),
            ],
          ),
        ),
        isThreeLine: true,
        // Menu de acciones (editar, equipo, eliminar)
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

  /// Color de avatar segun el rol.
  Color _colorRol(String? rol) {
    switch (rol) {
      case 'ADMINISTRACION':
        return Colors.purple;
      case 'GESTION':
        return Colors.blue;
      case 'JEFE_DE_OBRA':
        return Colors.black;
      case 'ENCARGADO':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Chip con el nombre del rol.
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

  /// Chip indicando si el usuario esta activo o inactivo.
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

  /// Dialogo de confirmacion para eliminar un usuario.
  void _confirmarEliminar(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario?'),
        content: const Text(
          'Esta accion no se puede deshacer y afectara a las asignaciones actuales.',
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
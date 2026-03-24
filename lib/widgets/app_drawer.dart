import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(authProvider).valueOrNull;
    if (perfil == null) return const SizedBox();

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(perfil.nombreCompleto),
            accountEmail: Text(perfil.email),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Mis partes'),
            onTap: () => context.go('/partes'),
          ),
          // Crear parte — todos los roles
          ListTile(
            leading: const Icon(Icons.add_box),
            title: const Text('Crear parte'),
            onTap: () => context.go('/partes/nuevo'),
          ),
          // Obras — todos excepto operario
          if (!perfil.esOperario)
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Obras'),
              onTap: () => context.go('/obras'),
            ),
          // Usuarios — solo gestión y admin
          if (perfil.esGestion)
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Usuarios'),
              onTap: () => context.go('/usuarios'),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

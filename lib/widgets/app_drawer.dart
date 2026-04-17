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
            // Añade esto:
            otherAccountsPictures: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/configuracion');
                },
              ),
            ],
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Mis partes'),
            onTap: () {
              Navigator.of(context).pop();
              context.go('/partes');
            },
          ),
          // Crear parte — solo operario y encargado
          if (perfil.puedeCrearParte)
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text('Crear parte'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/partes/nuevo');
              },
            ),
          // Obras — todos excepto operario
          if (!perfil.esOperario)
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Obras'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/obras');
              },
            ),
          // Usuarios — solo gestión y admin
          if (perfil.esGestion || perfil.esAdmin)
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Usuarios'),
              onTap: () {
                Navigator.of(context).pop(); // Cierra el drawer
                context.go('/usuarios');
              },
            ),
          if (perfil.esGestion || perfil.esAdmin)
            ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Quincena'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/quincena');
              },
            ),
          if (perfil.esGestion || perfil.esAdmin)
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Contabilidad Detallada'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/contabilidad-detalle');
              },
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

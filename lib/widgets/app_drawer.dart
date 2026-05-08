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

          // ── Partes ──────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Mis partes'),
            onTap: () {
              Navigator.of(context).pop();
              context.go('/partes');
            },
          ),
          if (perfil.puedeCrearParte)
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text('Crear parte'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/partes/nuevo');
              },
            ),

          // ── Obras ────────────────────────────────────────────────────────
          if (!perfil.esOperario)
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Obras'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/obras');
              },
            ),

          // ── Admin / Gestión ──────────────────────────────────────────────
          if (perfil.esGestion || perfil.esAdmin) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'ADMINISTRACIÓN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Usuarios'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/usuarios');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Resumen Quincena'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/quincena');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Quincena'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/contabilidad-detalle');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Fecha libre'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/fecha-libre');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Informe de partes'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/pdf-screen');
              },
            ),
          ],

          // ── Sesión ───────────────────────────────────────────────────────
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

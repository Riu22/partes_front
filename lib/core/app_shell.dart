import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_drawer.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _titleForLocation(context),
      ),
      drawer: const AppDrawer(),
      body: navigationShell,
    );
  }

  Widget _titleForLocation(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final titles = {
      '/partes': 'Mis Partes',
      '/partes/nuevo': 'Nuevo Parte',
      '/obras': 'Obras',
      '/usuarios': 'Usuarios',
    };
    return Text(titles[location] ?? 'Gestión de Partes');
  }
}

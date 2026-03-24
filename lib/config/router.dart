import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/partes/partes_screen.dart';
import '../screens/partes/crear_parte_screen.dart';
import '../screens/obras/obras_screen.dart';
import '../screens/admin/usuarios_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/partes',
    redirect: (context, state) {
      final perfil = auth.valueOrNull;
      final isLoggedIn = perfil != null;
      final location = state.matchedLocation;

      if (!isLoggedIn && location != '/login') return '/login';
      if (isLoggedIn && location == '/login') return '/partes';

      // --- PROTECCIÓN POR ROL ---
      // Usuarios: solo GESTION y ADMIN
      if (location == '/usuarios' &&
          perfil != null &&
          !perfil.esGestion &&
          !perfil.esAdmin) {
        return '/partes';
      }

      // Obras: no para operarios
      if (location == '/obras' && perfil != null && perfil.esOperario) {
        return '/partes';
      }

      return null;
    },
    routes: [
      // Ruta pública — sin shell
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),

      // Shell SPA — todas las rutas protegidas comparten AppShell (Drawer)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partes',
                builder: (_, _) => const PartesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/obras',
                builder: (_, _) => const ObrasScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/usuarios',
                builder: (_, _) => const UsuariosScreen(),
              ),
            ],
          ),
        ],
      ),

      // Ruta de creación de parte — fuera del shell (pantalla completa sin drawer)
      GoRoute(
        path: '/partes/nuevo',
        builder: (_, _) => const CrearParteScreen(),
      ),
    ],
  );
});

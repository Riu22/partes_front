import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/partes/partes_screen.dart';
import '../screens/partes/crear_parte_screen.dart';
import '../screens/obras/obras_screen.dart';
import '../screens/admin/usuarios_screen.dart';
import '../screens/configurarion_screen.dart';
import '../screens/NuevaPasswordScreen.dart';
import '../screens/admin/crear_usuarios_screen.dart';
import '../screens/admin/editar_usuarios_screen.dart';
import '../screens/admin/asignar_jefe_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/partes',
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (location == '/nueva-password') return null;

      final perfil = auth.valueOrNull;
      final isLoggedIn = perfil != null;
      if (!isLoggedIn && location != '/login') return '/login';
      if (isLoggedIn && location == '/login') return '/partes';

      if (location == '/usuarios' &&
          perfil != null &&
          !perfil.esGestion &&
          !perfil.esAdmin) {
        return '/partes';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      GoRoute(
        path: '/nueva-password',
        builder: (context, state) => const NuevaPasswordScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partes',
                builder: (context, state) => const PartesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/obras',
                builder: (context, state) => const ObrasScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/usuarios',
                builder: (context, state) => const UsuariosScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/partes/nuevo',
        builder: (context, state) => const CrearParteScreen(),
      ),
      GoRoute(
        path: '/configuracion',
        builder: (context, state) => const ConfiguracionScreen(),
      ),
      GoRoute(
        path: '/usuarios/nuevo',
        builder: (context, state) => const CrearUsuarioScreen(),
      ),
      GoRoute(
        path: '/usuarios/editar',
        builder: (context, state) {
          final u = state.extra as Map<String, dynamic>;
          return EditarUsuarioScreen(usuario: u);
        },
      ),
      GoRoute(
        path: '/usuarios/asignar-jefe',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return AsignarJefeScreen(
            usuario: extra['usuario'] as Map<String, dynamic>,
            todos: extra['todos'] as List<dynamic>,
          );
        },
      ),
    ],
  );
});

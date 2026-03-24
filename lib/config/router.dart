import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      final isLoggedIn = auth.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/partes';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/partes', builder: (_, _) => const PartesScreen()),
      GoRoute(
        path: '/partes/nuevo',
        builder: (_, _) => const CrearParteScreen(),
      ),
      GoRoute(path: '/obras', builder: (_, _) => const ObrasScreen()),
      GoRoute(path: '/usuarios', builder: (_, _) => const UsuariosScreen()),
    ],
  );
});

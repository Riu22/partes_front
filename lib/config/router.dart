import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/app_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/partes/partes_screen.dart';
import '../screens/partes/crear_parte_screen.dart';
import '../screens/partes/editar_partes_screen.dart';
import '../screens/partes/editar_partes_jefe_screen.dart';
import '../screens/obras/obras_screen.dart';
import '../screens/configurarion_screen.dart';
import '../screens/NuevaPasswordScreen.dart';
import '../models/parte_trabajo.dart';
import '../widgets/lazy_screen.dart';
import '../screens/admin/admin_entry.dart' deferred as admin;
import '../screens/report_entry.dart' deferred as report;

/// Notifica al router cuando cambia el estado de autenticación (login/logout).
/// Esto permite que GoRouter redirija automáticamente según si hay sesión o no.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

/// Proveedor del router de GoRouter con protección de rutas por rol.
/// Las reglas de navegación son:
/// 1. Si vas a /nueva-password, dejas pasar sin comprobar nada
/// 2. Si no hay sesión, redirige a /login
/// 3. Si ya tienes sesión y vas a /login, ve a /admin o /partes según tu rol
/// 4. Las rutas de admin solo para ADMINISTRACION y GESTION
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);
  ref.onDispose(notifier.dispose);

  bool esAdminOGestion(dynamic perfil) =>
      perfil != null && (perfil.esAdmin || perfil.esGestion);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      
      // ── 1. PRIORIDAD ABSOLUTA ──────────────────────────────────────────────
      // Si el usuario va a restablecer su contraseña, saltamos cualquier otra
      // comprobación (incluyendo si la autenticación está cargando o no).
      if (location == '/nueva-password') return null;

      // ── 2. ESTADO DE CARGA DE AUTH ─────────────────────────────────────────
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;

      // ── 3. CONTROL DE ACCESO Y LOGEO ───────────────────────────────────────
      final perfil = auth.valueOrNull;
      final isLoggedIn = perfil != null;

      if (!isLoggedIn && location != '/login') return '/login';

      if (isLoggedIn && location == '/login') {
        return esAdminOGestion(perfil) ? '/admin' : '/partes';
      }

      // ── 4. PROTECCIÓN DE RUTAS POR ROL ─────────────────────────────────────
      if (location == '/admin' && !esAdminOGestion(perfil)) return '/partes';
      if (location == '/usuarios' && !esAdminOGestion(perfil)) return '/partes';
      if (location == '/quincena' && !esAdminOGestion(perfil)) return '/partes';

      return null;
    },
    routes: [
      // ── Rutas públicas ─────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/nueva-password',
        builder: (context, state) => const NuevaPasswordScreen(),
      ),

      // ── Shell con barra de navegación ──────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Rama 0: admin
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (context, state) => LazyWidget(
                  loader: admin.loadLibrary,
                  builder: () => admin.makeAdminHomeScreen(),
                ),
              ),
            ],
          ),

          // Rama 1: partes
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partes',
                builder: (context, state) => const PartesScreen(),
                routes: [
                  GoRoute(
                    path: 'nuevo',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>?;
                      return CrearParteScreen(
                        perfilIdPreseleccionado: extra?['perfilId'] as String?,
                        nombrePreseleccionado: extra?['nombre'] as String?,
                        fechaPreseleccionada: extra?['fecha'] != null
                            ? DateTime.parse(extra!['fecha'] as String)
                            : null,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'editar',
                    builder: (context, state) {
                      final parte = state.extra as ParteTrabajo;
                      return EditarParteScreen(parte: parte);
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    redirect: (context, state) {
                      final id = state.pathParameters['id'];
                      if (int.tryParse(id ?? '') == null) return '/partes';
                      return null;
                    },
                    builder: (context, state) {
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      return PartesScreen(parteIdInicial: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Rama 2: obras
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/obras',
                builder: (context, state) => const ObrasScreen(),
              ),
            ],
          ),

          // Rama 3: usuarios
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/usuarios',
                builder: (context, state) => LazyWidget(
                  loader: admin.loadLibrary,
                  builder: () => admin.makeUsuariosScreen(),
                ),
              ),
            ],
          ),

          // Rama 4: quincena
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quincena',
                builder: (context, state) => LazyWidget(
                  loader: admin.loadLibrary,
                  builder: () => admin.makeContabilidadScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Rutas flotantes (fuera del shell, sin barra de navegación) ─────────
      GoRoute(
        path: '/partes/nuevo',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CrearParteScreen(
            perfilIdPreseleccionado: extra?['perfilId'] as String?,
            nombrePreseleccionado: extra?['nombre'] as String?,
            fechaPreseleccionada: extra?['fecha'] != null
                ? DateTime.parse(extra!['fecha'] as String)
                : null,
          );
        },
      ),
      GoRoute(
        path: '/partes/editar',
        builder: (context, state) {
          final parte = state.extra as ParteTrabajo;
          return EditarParteScreen(parte: parte);
        },
      ),
      GoRoute(
        path: '/partes/editar-jefe/:id',
        redirect: (context, state) {
          final perfil = ref.read(authProvider).valueOrNull;
          if (perfil == null ||
              (!perfil.esAdmin &&
                  !perfil.esGestion &&
                  !perfil.esJefeObra)) {
            return esAdminOGestion(perfil) ? '/admin' : '/partes';
          }
          return null;
        },
        builder: (context, state) {
          final parte = state.extra as Map<String, dynamic>?;
          if (parte == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => context.go('/partes'),
            );
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return EditarParteJefeScreen(parte: parte);
        },
      ),
      GoRoute(
        path: '/configuracion',
        builder: (context, state) => const ConfiguracionScreen(),
      ),
      GoRoute(
        path: '/usuarios/nuevo',
        builder: (context, state) => LazyWidget(
          loader: admin.loadLibrary,
          builder: () => admin.makeCrearUsuarioScreen(),
        ),
      ),
      GoRoute(
        path: '/usuarios/editar',
        builder: (context, state) {
          final u = state.extra as Map<String, dynamic>;
          return LazyWidget(
            loader: admin.loadLibrary,
            builder: () => admin.makeEditarUsuarioScreen(u),
          );
        },
      ),
      GoRoute(
        path: '/usuarios/asignar-jefe',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return LazyWidget(
            loader: admin.loadLibrary,
            builder: () => admin.makeAsignarJefeScreen(
              extra['usuario'] as Map<String, dynamic>,
              extra['todos'] as List<dynamic>,
            ),
          );
        },
      ),
      GoRoute(
        path: '/contabilidad-detalle',
        redirect: (context, state) {
          final perfil = ref.read(authProvider).valueOrNull;
          if (perfil == null ||
              (!perfil.esAdmin &&
                  !perfil.esGestion &&
                  !perfil.esJefeObra)) {
            return esAdminOGestion(perfil) ? '/admin' : '/partes';
          }
          return null;
        },
        builder: (context, state) => LazyWidget(
          loader: admin.loadLibrary,
          builder: () => admin.makeQuincenaScreen(),
        ),
      ),
      GoRoute(
        path: '/fecha-libre',
        redirect: (context, state) {
          final perfil = ref.read(authProvider).valueOrNull;
          if (!esAdminOGestion(perfil)) return '/partes';
          return null;
        },
        builder: (context, state) => LazyWidget(
          loader: admin.loadLibrary,
          builder: () => admin.makeFechaLibreScreen(),
        ),
      ),
      GoRoute(
        path: '/pdf-screen',
        redirect: (context, state) {
          final perfil = ref.read(authProvider).valueOrNull;
          if (perfil == null ||
              (!perfil.esAdmin &&
                  !perfil.esGestion &&
                  !perfil.esJefeObra)) {
            return '/partes';
          }
          return null;
        },
        builder: (context, state) => LazyWidget(
          loader: report.loadLibrary,
          builder: () => report.makeInformePartesScreen(),
        ),
      ),
      GoRoute(
        path: '/partes-jefe/informe',
        redirect: (context, state) {
          final perfil = ref.read(authProvider).valueOrNull;
          if (perfil == null ||
              (!perfil.esAdmin &&
                  !perfil.esGestion &&
                  !perfil.esJefeObra)) {
            return esAdminOGestion(perfil) ? '/admin' : '/partes';
          }
          return null;
        },
        builder: (context, state) => LazyWidget(
          loader: report.loadLibrary,
          builder: () => report.makeInformeJefeScreen(),
        ),
      ),
      GoRoute(
        path: '/partes-jefe/resumen',
        redirect: (context, state) {
          final perfil = ref.read(authProvider).valueOrNull;
          if (perfil == null ||
              (!perfil.esAdmin &&
                  !perfil.esGestion &&
                  !perfil.esJefeObra)) {
            return esAdminOGestion(perfil) ? '/admin' : '/partes';
          }
          return null;
        },
        builder: (context, state) => LazyWidget(
          loader: report.loadLibrary,
          builder: () => report.makeResumenMensualJefeScreen(),
        ),
      ),
    ],
  );
});
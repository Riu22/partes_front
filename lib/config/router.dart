// =============================================================================
// ARCHIVO:   router.dart
// PROPOSITO: Define el enrutador principal de la aplicacion usando GoRouter
//            con proteccion de rutas basada en autenticacion y roles.
//
//            GoRouter es un paquete de navegacion declarativa para Flutter
//            que usa URLs para identificar pantallas (similar a React Router
//            o Vue Router).  Soporta redirecciones, rutas anidadas, deep
//            linking, y navegacion con botones de retroceso del sistema.
//
//            Este archivo exporta routerProvider, un Provider<GoRouter> de
//            Riverpod que contiene TODAS las rutas de la aplicacion y la
//            logica de redireccion (auth guards).
//
// ESTRUCTURA DE RUTAS:
//
//   RUTAS PUBLICAS (sin proteccion):
//     /login           -> LoginScreen (inicio de sesion)
//     /nueva-password  -> NuevaPasswordScreen (restablecer contrasena)
//
//   SHELL PRINCIPAL (con barra de navegacion inferior):
//     StatefulShellRoute.indexedStack
//     Rama 0: /admin      -> AdminHomeScreen     (admin/gestion solamente)
//     Rama 1: /partes     -> PartesScreen        (todos los roles)
//       Subrutas:
//         /partes/nuevo   -> CrearParteScreen
//         /partes/editar  -> EditarParteScreen
//         /partes/:id     -> PartesScreen(parteIdInicial: id)
//     Rama 2: /obras      -> ObrasScreen         (todos los roles)
//     Rama 3: /usuarios   -> UsuariosScreen      (admin/gestion solamente)
//     Rama 4: /quincena   -> ContabilidadScreen  (admin/gestion solamente)
//
//   RUTAS FLOTANTES (fuera del shell, sin barra de navegacion):
//     /partes/nuevo          -> CrearParteScreen
//     /partes/editar         -> EditarParteScreen
//     /partes/editar-jefe/:id -> EditarParteJefeScreen (admin/gestion/jefe)
//     /configuracion         -> ConfiguracionScreen
//     /usuarios/nuevo        -> CrearUsuarioScreen
//     /usuarios/editar       -> EditarUsuarioScreen
//     /usuarios/asignar-jefe -> AsignarJefeScreen
//     /contabilidad-detalle  -> QuincenaScreen
//     /fecha-libre           -> FechaLibreScreen
//     /pdf-screen            -> InformePartesScreen
//     /partes-jefe/informe   -> InformeJefeScreen
//     /partes-jefe/resumen   -> ResumenMensualJefeScreen
//
// LOGICA DE REDIRECCION (authProvider):
//
//   1. Si el usuario va a /nueva-password -> PERMITIR SIEMPRE
//      (prioridad absoluta, ni siquiera comprueba si auth esta cargando)
//
//   2. Si authProvider.isLoading == true -> PERMITIR (esperar)
//      (no se puede decidir hasta que el estado de sesion este listo)
//
//   3. Si NO hay sesion y la ruta NO es /login -> REDIRIGIR A /login
//      (usuario no autenticado no puede ver ninguna pantalla protegida)
//
//   4. Si HAY sesion y la ruta ES /login -> REDIRIGIR
//      (usuario ya autenticado no necesita volver a login)
//        - Si es ADMIN o GESTION -> /admin
//        - Cualquier otro rol    -> /partes
//
//   5. PROTECCION POR ROL:
//      - /admin    -> solo ADMIN o GESTION (si no, a /partes)
//      - /usuarios -> solo ADMIN o GESTION (si no, a /partes)
//      - /quincena -> solo ADMIN o GESTION (si no, a /partes)
//
// CONCEPTOS DE GOROUTER EXPLICADOS:
//   - GoRouter:      Navegador declarativo.  Las rutas se definen como
//                    arbol de GoRoute.  La navegacion es via state.go(),
//                    state.push(), etc.
//   - redirect:      Funcion que se ejecuta en CADA navegacion.  Si
//                    devuelve null, la navegacion continua.  Si devuelve
//                    una ruta, se redirige a esa ruta.
//   - refreshListenable:  Objeto ChangeNotifier que, cuando notifica,
//                    hace que GoRouter re-evalue todos los redirects.
//                    Aqui se usa para reaccionar a cambios en authProvider.
//   - StatefulShellRoute.indexedStack:  Ruta que mantiene el estado de
//                    varias ramas hijas en un IndexedStack.  Cada rama
//                    conserva su estado aunque no este visible.  Perfecto
//                    para navegacion con barra inferior (BottomNavigationBar).
//   - StatefulShellBranch:  Una rama dentro de StatefulShellRoute.  Cada
//                    rama tiene su propio Navigator interno (su propia
//                    pila de historial).  Las ramas son independientes.
//   - LazyWidget:    Widget personalizado que carga pantallas con
//                    deferred import (carga diferida).  La pantalla solo
//                    se compila/descarga cuando se navega a ella por
//                    primera vez.  Reduce el tamano del APK inicial.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_shell.dart';
// app_shell.dart  Define AppShell, el Scaffold con AppBar y drawer que
// envuelve las pantallas dentro del StatefulShellRoute.

import '../providers/auth_provider.dart';
// auth_provider.dart  Define authProvider (un AsyncNotifierProvider que
// expone AsyncValue<PerfilUsuario?>).  Contiene el estado de autenticacion
// (usuario logueado o no, perfil, rol, etc.).

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

// Las siguientes pantallas se importan con "deferred as" (carga diferida).
// El codigo de estas pantallas solo se descarga cuando se navega a ellas
// por primera vez.  Esto reduce el tamano del APK inicial y acelera el
// arranque de la app.
import '../screens/admin/admin_entry.dart' deferred as admin;
import '../screens/report_entry.dart' deferred as report;

// =============================================================================
/// Notificador que avisa a GoRouter cuando cambia el estado de autenticacion.
///
/// GoRouter necesita un ChangeNotifier para re-evaluar los redirects cuando
/// el usuario inicia o cierra sesion (sin necesidad de recargar la app).
///
/// CONCEPTO FLUTTER:  ChangeNotifier es una clase que proporciona el patron
/// Observer (observable).  Cuando se llama a notifyListeners(), todos los
/// listeners registrados (en este caso GoRouter) se enteran del cambio.
///
/// GoRouter.registerRefreshListenable() escucha este notifier y, cuando
/// recibe la notificacion, ejecuta de nuevo la funcion redirect() para
/// todas las rutas activas.
/// =============================================================================
class _AuthNotifier extends ChangeNotifier {
  /// Constructor.  Se suscribe a cambios en authProvider usando ref.listen().
  /// Cada vez que authProvider cambia (login/logout), llama a
  /// notifyListeners() para que GoRouter re-evalue los redirects.
  _AuthNotifier(this._ref) {
    // ref.listen() ejecuta el callback cada vez que el valor del provider
    // cambia.  Ignoramos los valores anterior ( _ ) y nuevo ( _ ) porque
    // solo nos interesa notificar, no el contenido del cambio.
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }

  /// Referencia a Riverpod (Ref) para acceder a authProvider.
  /// Ref es la clase base de la que heredan WidgetRef, Reader, etc.
  /// Permite leer y escuchar providers sin ser un widget.
  final Ref _ref;
}

// =============================================================================
/// PROVEEDOR DEL ROUTER PRINCIPAL
///
/// Provider<GoRouter> que construye y expone el GoRouter con todas las
/// rutas y la logica de autenticacion.  Se consume en main.dart via
/// ref.watch(routerProvider) para pasarlo a MaterialApp.router().
///
/// REGLAS DE NAVEGACION (en orden de prioridad):
/// 1. /nueva-password  -> Permitir siempre (prioridad absoluta)
/// 2. auth cargando    -> Permitir (esperar a que termine)
/// 3. Sin sesion       -> Redirigir a /login (si no esta ya en /login)
/// 4. Con sesion en /login -> Redirigir a /admin (admin/gestion) o /partes
/// 5. Rutas protegidas por rol -> Redirigir si no tiene permiso
/// =============================================================================
final routerProvider = Provider<GoRouter>((ref) {
  // --- CREAR EL NOTIFICADOR DE AUTENTICACION -------------------------------
  // _AuthNotifier se suscribe a authProvider y notifica a GoRouter cuando
  // cambia la sesion.  Se pasa como refreshListenable en GoRouter().
  final notifier = _AuthNotifier(ref);

  // onDispose:  Cuando el Provider se destruye (ej: la app se cierra),
  // tambien se destruye el notifier para evitar memory leaks.
  ref.onDispose(notifier.dispose);

  // --- FUNCION AUXILIAR: VERIFICAR ROL ADMIN O GESTION --------------------
  // Comprueba si el perfil tiene rol ADMINISTRACION (esAdmin) o GESTION
  // (esGestion).  Estos roles tienen acceso a las rutas administrativas.
  bool esAdminOGestion(dynamic perfil) =>
      perfil != null && (perfil.esAdmin || perfil.esGestion);

  // =========================================================================
  // CONSTRUIR EL GOROUTER
  // =========================================================================
  return GoRouter(
    // --- RUTA INICIAL ------------------------------------------------------
    // La primera pantalla que se muestra al abrir la app.
    // Si el usuario ya tiene sesion (token valido en authProvider), el
    // redirect lo enviara a /admin o /partes inmediatamente.
    initialLocation: '/login',

    // --- REFRESH LISTENABLE ------------------------------------------------
    // GoRouter escucha este ChangeNotifier.  Cuando notifier llama a
    // notifyListeners(), GoRouter re-ejecuta redirect() en TODAS las
    // rutas activas, permitiendo redirigir al usuario si su sesion
    // cambio (ej: cerro sesion en otra pestana, token expiro).
    refreshListenable: notifier,

    // =======================================================================
    // FUNCION DE REDIRECCION GLOBAL (auth guard)
    // =======================================================================
    // Se ejecuta en CADA navegacion (cada vez que el usuario intenta
    // cambiar de pantalla).  Recibe el contexto y el estado actual del
    // router.  Si devuelve null, la navegacion continua sin cambios.
    // Si devuelve una ruta (String), se redirige a esa ruta.
    //
    // CONCEPTO GOROUTER:  redirect es como un middleware.  Se ejecuta
    // antes de construir cualquier pantalla.  Permite interceptar la
    // navegacion y desviarla si es necesario (proteccion de rutas).
    redirect: (context, state) {
      // matchedLocation:  la ruta actual (URL) que el usuario esta
      // intentando visitar.  Ej: "/admin", "/partes/nuevo", etc.
      final location = state.matchedLocation;

      // =====================================================================
      // PASO 1:  PRIORIDAD ABSOLUTA - RUTA DE NUEVA CONTRASENA
      // =====================================================================
      // Si el usuario va a restablecer su contrasena, NO hacemos ninguna
      // comprobacion de autenticacion.  Esta ruta debe ser accesible
      // incluso si:
      //   - El usuario no tiene sesion (obvio, la olvido)
      //   - authProvider esta cargando
      //   - El token expiro
      //   - Cualquier otro estado
      //
      // Esto es fundamental porque un usuario que olvido su contrasena NO
      // puede iniciar sesion, pero SI necesita acceder a esta pantalla
      // para crear una contrasena nueva.
      if (location == '/nueva-password') return null;

      // =====================================================================
      // PASO 2:  ESPERAR A QUE AUTH PROVIDER CARGUE
      // =====================================================================
      // Si authProvider aun esta resolviendo (comprobando token guardado,
      // refrescando sesion, etc.), permitimos la navegacion temporalmente.
      // Si redirigieramos mientras isLoading == true, el usuario podria
      // ser enviado a /login aunque tenga sesion (porque el provider aun
      // no ha devuelto el valor final).
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;

      // =====================================================================
      // PASO 3:  CONTROL DE ACCESO (logueado / no logueado)
      // =====================================================================
      // valueOrNull devuelve el perfil si el provider se resolvio
      // exitosamente, o null si el usuario NO tiene sesion (o el token
      // es invalido/expiro).
      final perfil = auth.valueOrNull;

      // isLoggedIn:  true si hay un perfil de usuario (sesion activa).
      final isLoggedIn = perfil != null;

      // --- 3.1:  NO HAY SESION Y NO ESTA EN LOGIN -> REDIRIGIR A LOGIN ----
      // Si el usuario no esta autenticado y no esta en la pantalla de
      // login, lo enviamos a /login para que inicie sesion.
      if (!isLoggedIn && location != '/login') return '/login';

      // --- 3.2:  HAY SESION Y ESTA EN LOGIN -> REDIRIGIR SEGUN ROL --------
      // Si el usuario ya tiene sesion pero intenta ir a /login, no tiene
      // sentido.  Lo redirigimos a la pantalla principal segun su rol.
      if (isLoggedIn && location == '/login') {
        // Admin y Gestion van al panel de administracion.
        // Los demas roles (Jefe de Obra, Trabajador) van a la pantalla
        // de partes.
        return esAdminOGestion(perfil) ? '/admin' : '/partes';
      }

      // =====================================================================
      // PASO 4:  PROTECCION DE RUTAS POR ROL
      // =====================================================================
      // Si el usuario intenta acceder a una ruta administrativa pero no
      // tiene el rol adecuado, lo redirigimos a /partes (su pantalla
      // principal).

      // /admin:  Panel de administracion
      // Solo ADMINISTRACION y GESTION pueden verlo.
      if (location == '/admin' && !esAdminOGestion(perfil)) return '/partes';

      // /usuarios:  Gestion de usuarios
      // Solo ADMINISTRACION y GESTION pueden verlo.
      if (location == '/usuarios' && !esAdminOGestion(perfil)) return '/partes';

      // /quincena:  Pantalla de contabilidad / quincena
      // Solo ADMINISTRACION y GESTION pueden verlo.
      if (location == '/quincena' && !esAdminOGestion(perfil)) return '/partes';

      // Si no se cumple ninguna condicion de redireccion, devolvemos null
      // para permitir que la navegacion continue normalmente.
      return null;
    },

    // =======================================================================
    // DEFINICION DE RUTAS
    // =======================================================================
    routes: [
      // =====================================================================
      // RUTAS PUBLICAS (sin proteccion, accesibles sin sesion)
      // =====================================================================

      // --- /login:  Pantalla de inicio de sesion ---------------------------
      // Ruta publica.  El redirect la protege: si hay sesion, redirige a
      // /admin o /partes.  Si no hay sesion, permite el acceso.
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // --- /nueva-password:  Restablecer contrasena -------------------------
      // Ruta publica con PRIORIDAD ABSOLUTA en el redirect.  Se salta
      // todas las comprobaciones de autenticacion.  Necesaria para que
      // los usuarios que olvidaron su contrasena puedan recuperarla.
      GoRoute(
        path: '/nueva-password',
        builder: (context, state) => const NuevaPasswordScreen(),
      ),

      // =====================================================================
      // SHELL PRINCIPAL CON BARRA DE NAVEGACION INFERIOR
      // =====================================================================
      // StatefulShellRoute.indexedStack mantiene el estado de cada rama.
      // Cuando el usuario cambia de pestana, la rama anterior NO se
      // destruye, solo se oculta.  Al volver, la pantalla esta exactamente
      // como se dejo (scroll position, formularios parcialmente llenos,
      // etc.).  Esto se logra con IndexedStack internamente.
      //
      // CONCEPTO FLUTTER:  IndexedStack es un widget que muestra UNO de
      // sus hijos (segun un indice) y mantiene a los demas hijos montados
      // pero invisibles.  Todos los hijos conservan su estado.
      StatefulShellRoute.indexedStack(
        // builder:  Construye el widget que envuelve las ramas.
        // AppShell es un Scaffold con AppBar y drawer.  navigationShell
        // es el widget que GoRouter proporciona para manejar la navegacion
        // entre ramas (contiene el IndexedStack y el control de pestanas).
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),

        // branches:  Lista de ramas.  Cada rama tiene su propio Navigator
        // y su propia pila de historial.  La rama activa se muestra en
        // la pantalla; las demas se mantienen en segundo plano.
        branches: [
          // =================================================================
          // RAMA 0: ADMIN (Panel de administracion)
          // =================================================================
          // Solo accesible para ADMINISTRACION y GESTION (protegido en
          // el redirect global, paso 4).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                builder: (context, state) => LazyWidget(
                  // Carga diferida: admin_entry.dart solo se descarga
                  // cuando el usuario navega a /admin por primera vez.
                  loader: admin.loadLibrary,
                  builder: () => admin.makeAdminHomeScreen(),
                ),
              ),
            ],
          ),

          // =================================================================
          // RAMA 1: PARTES (Partes de trabajo)
          // =================================================================
          // Accesible para TODOS los roles autenticados.
          // Es la pantalla principal para trabajadores y jefes de obra.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/partes',
                builder: (context, state) => const PartesScreen(),
                // Subrutas de /partes (rutas hijas, dentro del shell)
                routes: [
                  // --- /partes/nuevo:  Crear nuevo parte --------------------
                  GoRoute(
                    path: 'nuevo',
                    builder: (context, state) {
                      // state.extra:  Datos opcionales pasados al navegar.
                      // Aqui se pasan valores preseleccionados (perfil,
                      // nombre, fecha) para precargar el formulario.
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

                  // --- /partes/editar:  Editar parte existente --------------
                  GoRoute(
                    path: 'editar',
                    builder: (context, state) {
                      // El parte a editar se pasa completo en state.extra
                      // como un objeto ParteTrabajo.
                      final parte = state.extra as ParteTrabajo;
                      return EditarParteScreen(parte: parte);
                    },
                  ),

                  // --- /partes/:id:  Ver detalle de un parte por ID --------
                  GoRoute(
                    path: ':id',
                    // redirect de validacion:  Si el parametro :id no es
                    // un numero entero valido, redirige a /partes (lista).
                    redirect: (context, state) {
                      final id = state.pathParameters['id'];
                      // int.tryParse devuelve null si el string no es un
                      // numero.  Si es null, redirigimos a /partes.
                      if (int.tryParse(id ?? '') == null) return '/partes';
                      return null;
                    },
                    builder: (context, state) {
                      // Una vez validado el ID, lo convertimos a int y
                      // pasamos a PartesScreen con parteIdInicial para que
                      // se abra directamente el detalle de ese parte.
                      final id = int.tryParse(state.pathParameters['id'] ?? '');
                      return PartesScreen(parteIdInicial: id);
                    },
                  ),
                ],
              ),
            ],
          ),

          // =================================================================
          // RAMA 2: OBRAS (Lista de obras)
          // =================================================================
          // Accesible para TODOS los roles autenticados.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/obras',
                builder: (context, state) => const ObrasScreen(),
              ),
            ],
          ),

          // =================================================================
          // RAMA 3: USUARIOS (Gestion de usuarios)
          // =================================================================
          // Solo accesible para ADMINISTRACION y GESTION.
          // Protegido en el redirect global (paso 4).
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

          // =================================================================
          // RAMA 4: QUINCENA (Contabilidad / quincena)
          // =================================================================
          // Solo accesible para ADMINISTRACION y GESTION.
          // Protegido en el redirect global (paso 4).
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

      // =====================================================================
      // RUTAS FLOTANTES (fuera del shell, sin barra de navegacion)
      // =====================================================================
      // Estas rutas se definen fuera del StatefulShellRoute, por lo que
      // NO tienen la barra de navegacion inferior ni el drawer.  Son
      // pantallas independientes que ocupan toda la pantalla (modales,
      // formularios de edicion, etc.).

      // --- /partes/nuevo:  Crear parte (fuera del shell) -------------------
      // Duplicado de la subruta dentro del shell, pero esta version se
      // navega desde fuera (ej: desde una notificacion o un deep link).
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

      // --- /partes/editar:  Editar parte (fuera del shell) -----------------
      GoRoute(
        path: '/partes/editar',
        builder: (context, state) {
          final parte = state.extra as ParteTrabajo;
          return EditarParteScreen(parte: parte);
        },
      ),

      // --- /partes/editar-jefe/:id:  Editar parte como jefe de obra --------
      // Ruta protegida por rol:  solo ADMIN, GESTION o JEFE_OBRA.
      // El redirect es INLINE (dentro de la ruta misma), no global.
      GoRoute(
        path: '/partes/editar-jefe/:id',
        redirect: (context, state) {
          // Leer el perfil actual desde authProvider.
          final perfil = ref.read(authProvider).valueOrNull;
          // Si no hay perfil, o el perfil no es admin/gestion/jefeObra,
          // redirigir a la pantalla principal segun el rol.
          if (perfil == null ||
              (!perfil.esAdmin &&
                  !perfil.esGestion &&
                  !perfil.esJefeObra)) {
            return esAdminOGestion(perfil) ? '/admin' : '/partes';
          }
          return null;
        },
        builder: (context, state) {
          // El parte se pasa como Map<String, dynamic> en state.extra.
          final parte = state.extra as Map<String, dynamic>?;
          if (parte == null) {
            // Si no se paso el parte (navegacion incorrecta), redirigir
            // a /partes despues del frame actual (usando
            // addPostFrameCallback) y mientras tanto mostrar un spinner.
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

      // --- /configuracion:  Pantalla de configuracion ----------------------
      GoRoute(
        path: '/configuracion',
        builder: (context, state) => const ConfiguracionScreen(),
      ),

      // --- /usuarios/nuevo:  Crear nuevo usuario ---------------------------
      GoRoute(
        path: '/usuarios/nuevo',
        builder: (context, state) => LazyWidget(
          loader: admin.loadLibrary,
          builder: () => admin.makeCrearUsuarioScreen(),
        ),
      ),

      // --- /usuarios/editar:  Editar usuario existente ---------------------
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

      // --- /usuarios/asignar-jefe:  Asignar jefe a un usuario ---------------
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

      // --- /contabilidad-detalle:  Detalle de quincena contable ------------
      // Ruta protegida:  solo ADMIN, GESTION o JEFE_OBRA.
      // Usa redirect INLINE.
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

      // --- /fecha-libre:  Gestion de fechas libres -------------------------
      // Ruta protegida:  solo ADMIN y GESTION (esAdminOGestion).
      // Usa redirect INLINE.
      GoRoute(
        path: '/fecha-libre',
        redirect: (context, state) {
          final perfil = ref.read(authProvider).valueOrNull;
          // Si no es admin ni gestion, redirigir a /partes.
          if (!esAdminOGestion(perfil)) return '/partes';
          return null;
        },
        builder: (context, state) => LazyWidget(
          loader: admin.loadLibrary,
          builder: () => admin.makeFechaLibreScreen(),
        ),
      ),

      // --- /pdf-screen:  Generar/ver informes en PDF -----------------------
      // Ruta protegida:  solo ADMIN, GESTION o JEFE_OBRA.
      // Usa redirect INLINE.  Carga report_entry.dart de forma diferida.
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

      // --- /partes-jefe/informe:  Informe de partes para jefe de obra ------
      // Ruta protegida:  solo ADMIN, GESTION o JEFE_OBRA.
      // Usa redirect INLINE.  Carga report_entry.dart de forma diferida.
      GoRoute(
        path: '/partes-jefe/informe',
        redirect: (context, state) {
          final perfil = ref.read(authProvider).valueOrNull;
          if (perfil == null ||
              (!perfil.esAdmin &&
                  !perfil.esGestion &&
                  !perfil.esJefeObra)) {
            // Redirigir a la pantalla principal segun el rol.
            return esAdminOGestion(perfil) ? '/admin' : '/partes';
          }
          return null;
        },
        builder: (context, state) => LazyWidget(
          loader: report.loadLibrary,
          builder: () => report.makeInformeJefeScreen(),
        ),
      ),

      // --- /partes-jefe/resumen:  Resumen mensual para jefe de obra --------
      // Ruta protegida:  solo ADMIN, GESTION o JEFE_OBRA.
      // Usa redirect INLINE.  Carga report_entry.dart de forma diferida.
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

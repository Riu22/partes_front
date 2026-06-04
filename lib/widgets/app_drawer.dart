// =============================================================================
// app_drawer.dart  -  Menu lateral de navegacion (Drawer)
// =============================================================================
// ASPECTO EN PANTALLA:
//   Panel que se desliza desde la izquierda al tocar el icono de hamburguesa.
//   Arriba muestra la foto, nombre y email del usuario logueado + icono de
//   configuracion. Debajo aparecen listas de opciones agrupadas por secciones:
//   "Partes", "Obras", "DATOS" (jefe de obra) y "ADMINISTRACION" (admin/gestion).
//   Al final esta siempre "Cerrar sesion".
//
// USO:
//   Navegacion principal de la app. Sustituye al menu inferior tradicional.
//   Cada opcion navega a una pantalla distinta mediante go_router.
//
// DATOS QUE NECESITA:
//   - authProvider (Riverpod): para conocer el perfil del usuario logueado
//     (nombre, email, roles: esOperario, esJefeObra, esGestion, esAdmin,
//      puedeCrearParte).
//
// INTERACCION DEL USUARIO:
//   - Tocar cualquier opcion: cierra el drawer y navega a la ruta.
//   - Tocar el icono de ajustes (engranaje): va a /configuracion.
//   - Tocar "Cerrar sesion": llama a logout() y redirige a /login.
// =============================================================================

/// Menú lateral de navegación (Drawer).
/// Muestra enlaces a las secciones según el rol del usuario:
/// operario, jefe de obra, administrador o gestión.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// Widget que construye el menú lateral completo.
/// Dependiendo del perfil del usuario muestra opciones como:
/// Mis partes, Crear parte, Obras, Detalle de horas, Informes, Admin, etc.
///
/// [ConsumerWidget] es un StatelessWidget que tiene acceso a [WidgetRef]
/// para escuchar (watch) providers de Riverpod sin necesidad de crear un
/// StatefulWidget. ref.watch() se usa para leer y reaccionar a cambios.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lee el perfil del usuario desde el provider de autenticacion.
    // valueOrNull devuelve null si aun no se ha cargado.
    final perfil = ref.watch(authProvider).valueOrNull;

    // Si no hay perfil (no ha cargado), muestra un SizedBox vacio.
    if (perfil == null) return const SizedBox();

    return Drawer(
      // [Drawer] es el panel lateral de Material Design.
      // Se desliza desde el borde izquierdo.
      child: ListView(
        // [ListView] permite scroll vertical.
        // padding: EdgeInsets.zero elimina el padding por defecto.
        padding: EdgeInsets.zero,
        children: [
          // ── CABECERA DEL DRAWER ──────────────────────────────
          // Muestra la informacion basica del usuario logueado.
          UserAccountsDrawerHeader(
            accountName: Text(perfil.nombreCompleto),
            accountEmail: Text(perfil.email),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            // otherAccountsPictures se usa aqui para colocar el boton
            // de configuracion en la esquina superior derecha del header.
            otherAccountsPictures: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  // Cierra el drawer primero, luego navega.
                  Navigator.of(context).pop();
                  context.push('/configuracion');
                },
              ),
            ],
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          ),

          // ── PARTES ──────────────────────────────────────────
          // Seccion visible para todos los usuarios.
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Mis partes'),
            onTap: () {
              Navigator.of(context).pop();
              context.go('/partes');
            },
          ),
          // Solo usuarios con permiso pueden crear partes.
          if (perfil.puedeCrearParte)
            ListTile(
              leading: const Icon(Icons.add_box),
              title: const Text('Crear parte'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/partes/nuevo');
              },
            ),

          // ── OBRAS ────────────────────────────────────────────
          // Seccion oculta para operarios (solo jefes, admin, gestion).
          if (!perfil.esOperario)
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Obras'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/obras');
              },
            ),

          // ── JEFE DE OBRA ─────────────────────────────────────
          // Solo visible si el perfil tiene rol de jefe de obra.
          if (perfil.esJefeObra) ...[
            const Divider(),
            // Subtitulo de seccion "DATOS"
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'DATOS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            // Detalle de horas trabajadas
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Detalle de horas'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/contabilidad-detalle');
              },
            ),
            // Informe de dedicacion a obras
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('Informe de dedicación'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/partes-jefe/informe');
              },
            ),
            // Informe de partes en PDF
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Informe de partes'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/pdf-screen');
              },
            ),
          ],

          // ── ADMIN / GESTION ──────────────────────────────────
          // Solo visible para roles de gestion o administrador.
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
            // Panel de administracion general
            ListTile(
              leading: const Icon(Icons.dashboard_rounded),
              title: const Text('Panel de administración'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/admin');
              },
            ),
            // Gestion de usuarios
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Usuarios'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/usuarios');
              },
            ),
            // Vista de quincena
            ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Quincena'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/quincena');
              },
            ),
            // Personal activo
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Personal Activo'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/contabilidad-detalle');
              },
            ),
            // Autorizaciones de fechas
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Autorizaciones'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/fecha-libre');
              },
            ),
            // Informe de partes PDF
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Informe de partes'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/pdf-screen');
              },
            ),
            // Dedicacion mensual
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Dedicación mensual'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/partes-jefe/resumen');
              },
            ),
          ],

          // ── CERRAR SESION ────────────────────────────────────
          // Siempre visible. Cierra sesion y redirige al login.
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              // Llama al notifier del provider de autenticacion para
              // limpiar el token y los datos de sesion.
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// admin_entry.dart
// =============================================================================
// QUE ES:       Punto de entrada diferido (lazy) para las pantallas del
//               modulo de administracion.
// PARA QUE:     Centralizar la creacion de pantallas admin para usar con
//               go_router (lazy loading).
// QUIEN LO USA: Sistema de rutas (go_router) al navegar a /admin/*.
// COMO SE LLEGA: Se importa desde el router; no es una pantalla en si misma.
// A DONDE VA:   No va al servidor; solo instancia widgets.
// QUE DATOS USA: Ninguno directamente; pasa datos a las pantallas hijas.
// OFFLINE:      No aplica.
// =============================================================================

import 'package:flutter/material.dart';
import 'admin_home_screen.dart';
import 'usuarios_screen.dart';
import 'crear_usuarios_screen.dart';
import 'editar_usuarios_screen.dart';
import 'asignar_jefe_screen.dart';
import 'quincena_screen.dart';
import 'dias_quincena_screen.dart';
import 'fecha_libre_screen.dart';

/// Crea la pantalla de inicio del panel de administracion.
Widget makeAdminHomeScreen() => const AdminHomeScreen();

/// Crea la pantalla de listado de usuarios.
Widget makeUsuariosScreen() => const UsuariosScreen();

/// Crea la pantalla para crear un nuevo usuario.
Widget makeCrearUsuarioScreen() => const CrearUsuarioScreen();

/// Crea la pantalla para editar un usuario existente.
Widget makeEditarUsuarioScreen(Map<String, dynamic> usuario) =>
    EditarUsuarioScreen(usuario: usuario);

/// Crea la pantalla para asignar jefe/equipo a un usuario.
Widget makeAsignarJefeScreen(
    Map<String, dynamic> usuario, List<dynamic> todos) =>
    AsignarJefeScreen(usuario: usuario, todos: todos);

/// Crea la pantalla de informe de quincena (exportacion contable).
Widget makeQuincenaScreen() => const QuincenaScreen();

/// Crea la pantalla de detalle de dias de la quincena por trabajador.
Widget makeContabilidadScreen() => const ContabilidadScreen();

/// Crea la pantalla de gestion de fechas libres por operario.
Widget makeFechaLibreScreen() => const FechaLibreScreen();

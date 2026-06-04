/// Punto de entrada diferido (lazy) para las pantallas del módulo de
/// administración: inicio, usuarios (listar, crear, editar, asignar jefe),
/// informes contables (quincena, detalle de días) y gestión de fechas libres.
import 'package:flutter/material.dart';
import 'admin_home_screen.dart';
import 'usuarios_screen.dart';
import 'crear_usuarios_screen.dart';
import 'editar_usuarios_screen.dart';
import 'asignar_jefe_screen.dart';
import 'quincena_screen.dart';
import 'dias_quincena_screen.dart';
import 'fecha_libre_screen.dart';

/// Crea la pantalla de inicio del panel de administración.
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

/// Crea la pantalla de informe de quincena (exportación contable).
Widget makeQuincenaScreen() => const QuincenaScreen();

/// Crea la pantalla de detalle de días de la quincena por trabajador.
Widget makeContabilidadScreen() => const ContabilidadScreen();

/// Crea la pantalla de gestión de fechas libres por operario.
Widget makeFechaLibreScreen() => const FechaLibreScreen();

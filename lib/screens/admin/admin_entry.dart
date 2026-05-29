import 'package:flutter/material.dart';
import 'admin_home_screen.dart';
import 'usuarios_screen.dart';
import 'crear_usuarios_screen.dart';
import 'editar_usuarios_screen.dart';
import 'asignar_jefe_screen.dart';
import 'quincena_screen.dart';
import 'dias_quincena_screen.dart';
import 'fecha_libre_screen.dart';

Widget makeAdminHomeScreen() => const AdminHomeScreen();
Widget makeUsuariosScreen() => const UsuariosScreen();
Widget makeCrearUsuarioScreen() => const CrearUsuarioScreen();
Widget makeEditarUsuarioScreen(Map<String, dynamic> usuario) =>
    EditarUsuarioScreen(usuario: usuario);
Widget makeAsignarJefeScreen(
    Map<String, dynamic> usuario, List<dynamic> todos) =>
    AsignarJefeScreen(usuario: usuario, todos: todos);
Widget makeQuincenaScreen() => const QuincenaScreen();
Widget makeContabilidadScreen() => const ContabilidadScreen();
Widget makeFechaLibreScreen() => const FechaLibreScreen();

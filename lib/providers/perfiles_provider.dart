/// Proveedor de perfiles de usuario.
///
/// Obtiene la lista de todos los usuarios del sistema
/// desde el servidor. Se usa para mostrar la lista de
/// trabajadores y sus datos.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/perfil.dart';
import 'auth_provider.dart';

/// Provee la lista de todos los perfiles de usuario registrados.
///
/// Hace una petición al servidor y convierte cada usuario
/// en un objeto [Perfil] para usarlo en la interfaz.
final perfilesProvider = FutureProvider<List<Perfil>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getUsuarios();
  return data.map((e) => Perfil.fromJson(e)).toList();
});

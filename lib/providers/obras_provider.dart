/// Proveedor de obras.
///
/// Obtiene la lista de obras desde el servidor.
/// Si falla la conexión, usa los datos guardados en el teléfono
/// (caché) para mostrar las obras sin necesidad de internet.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/obra.dart';
import 'auth_provider.dart';

/// Provee la lista completa de obras.
///
/// Carga las obras desde el servidor. Si falla la conexión,
/// usa la copia guardada en caché. Si no hay caché ni conexión,
/// devuelve una lista vacía.
final obrasProvider = FutureProvider<List<Obra>>((ref) async {
  ref.keepAlive();
  final perfil = await ref.watch(authProvider.future);
  if (perfil == null) return [];

  final api = ref.read(apiServiceProvider);
  final prefs = await SharedPreferences.getInstance();
  const cacheKey = 'cache_obras_lista';

  try {
    final data = await api.getObras();
    await prefs.setString(cacheKey, jsonEncode(data));
    return data.map((e) => Obra.fromJson(e)).toList();
  } catch (e) {
    final cacheGuardada = prefs.getString(cacheKey);
    if (cacheGuardada != null) {
      final List<dynamic> lista = jsonDecode(cacheGuardada);
      return lista.map((e) => Obra.fromJson(e)).toList();
    }
    return [];
  }
});

/// Provee solo las obras que están activas actualmente.
///
/// Similar a [obrasProvider] pero filtrando únicamente
/// las obras en estado activo. También usa caché como respaldo.
final obrasActivasProvider = FutureProvider<List<Obra>>((ref) async {
  ref.keepAlive();
  final perfil = await ref.watch(authProvider.future);
  if (perfil == null) return [];

  final api = ref.read(apiServiceProvider);
  final prefs = await SharedPreferences.getInstance();
  const cacheKey = 'cache_obras_activas';

  try {
    final data = await api.getObrasActivas();
    await prefs.setString(cacheKey, jsonEncode(data));
    return data.map((e) => Obra.fromJson(e)).toList();
  } catch (e) {
    final cacheGuardada = prefs.getString(cacheKey);
    if (cacheGuardada != null) {
      final List<dynamic> lista = jsonDecode(cacheGuardada);
      return lista.map((e) => Obra.fromJson(e)).toList();
    }
    return [];
  }
});
/// Provee las obras asignadas al usuario actual.
///
/// Obtiene del servidor las obras donde el usuario está asignado
/// como trabajador.
final misAsignacionesProvider = FutureProvider<List<dynamic>>((ref) async {
  return await ref.read(apiServiceProvider).getMisObras();
});
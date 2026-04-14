import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parte_trabajo.dart';
import 'auth_provider.dart';

const _cacheKeyPartes = 'cache_partes_lista';

final partesProvider = FutureProvider<List<ParteTrabajo>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final prefs = await SharedPreferences.getInstance();

  try {
    final data = await api.getPartes();
    // Guardar en cache para uso offline
    await prefs.setString(_cacheKeyPartes, jsonEncode(data));
    return data.map((e) => ParteTrabajo.fromJson(e)).toList();
  } catch (e) {
    // Sin conexión: devolver la última lista guardada
    final cache = prefs.getString(_cacheKeyPartes);
    if (cache != null) {
      final List<dynamic> lista = jsonDecode(cache);
      return lista.map((e) => ParteTrabajo.fromJson(e)).toList();
    }
    return []; // Sin cache y sin red: lista vacía
  }
});

final partesJefeProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getPartesJefe();
  return data;
});

final busquedaPartesProvider =
    FutureProvider.family<List<dynamic>, Map<String, String?>>((
      ref,
      filtros,
    ) async {
      return await ref
          .read(apiServiceProvider)
          .buscarPartes(
            obra: filtros['obra'],
            operario: filtros['operario'],
            especialidad: filtros['especialidad'],
          );
    });

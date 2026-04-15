import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/obra.dart';
import 'auth_provider.dart';

final obrasProvider = FutureProvider<List<Obra>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final prefs = await SharedPreferences.getInstance();
  const cacheKey = 'cache_obras_lista';

  try {
    // 1. Intentamos traer las obras del servidor (con el timeout de 5s que pusimos en ApiService)
    final data = await api.getObras();

    // 2. Si hay éxito, guardamos una copia en el móvil (como un "seguro de vida")
    await prefs.setString(cacheKey, jsonEncode(data));

    // 3. Devolvemos la lista fresca
    return data.map((e) => Obra.fromJson(e)).toList();
  } catch (e) {
    final cacheGuardada = prefs.getString(cacheKey);
    if (cacheGuardada != null) {
      final List<dynamic> lista = jsonDecode(cacheGuardada);
      // Devolvemos la lista en lugar de hacer un 'throw'
      // Esto hace que el Provider pase a estado 'Data' con datos viejos, no a estado 'Error'
      return lista.map((e) => Obra.fromJson(e)).toList();
    }
    return []; // Si no hay nada, lista vacía para que la UI no explote
  }
});

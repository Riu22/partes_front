import 'dart:convert'; // Necesario para jsonEncode/jsonDecode
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
    // 4. SI HAY ERROR (porque no hay internet o el servidor no responde):
    final cacheGuardada = prefs.getString(cacheKey);

    if (cacheGuardada != null) {
      // 5. ¡Rescate! Cargamos lo que guardamos la última vez que hubo red
      final List<dynamic> listaDecodificada = jsonDecode(cacheGuardada);
      return listaDecodificada.map((e) => Obra.fromJson(e)).toList();
    }

    // 6. Si es la primera vez que usa la app y no hay ni red ni caché, lanzamos el error
    throw Exception(
      "No hay conexión y no existen datos locales. Conéctate una vez para descargar las obras.",
    );
  }
});

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/obra.dart';
import 'auth_provider.dart';

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

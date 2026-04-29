import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/perfil.dart';
import 'auth_provider.dart';

final perfilesProvider = FutureProvider<List<Perfil>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final data = await api.getUsuarios();
  return data.map((e) => Perfil.fromJson(e)).toList();
});

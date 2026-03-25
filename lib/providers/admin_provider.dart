import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final usuariosProvider = FutureProvider<List<dynamic>>((ref) async {
  return await ref.read(apiServiceProvider).getUsuarios();
});

final asignacionesObraProvider = FutureProvider.family<List<dynamic>, int>((
  ref,
  obraId,
) async {
  return await ref.read(apiServiceProvider).getAsignacionesObra(obraId);
});
final misObrasProvider = FutureProvider<List<dynamic>>((ref) async {
  return await ref.read(apiServiceProvider).getMisObras();
});

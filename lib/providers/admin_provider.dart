import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ausencia_info.dart';
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

final diasSinParteProvider =
    FutureProvider.autoDispose<Map<String, AusenciaInfo>>((ref) async {
      final api = ref.read(apiServiceProvider);
      final raw = await api.getDiasSinParte();

      return raw.map((uuid, value) {
        final info = value as Map<String, dynamic>;
        final infoConId = {'perfilId': uuid, ...info};
        return MapEntry(uuid, AusenciaInfo.fromJson(infoConId));
      });
    });

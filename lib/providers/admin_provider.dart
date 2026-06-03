import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ausencia_info.dart';
import '../models/obra.dart';
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

final misObrasProvider = FutureProvider<List<Obra>>((ref) async {
  final data = await ref.read(apiServiceProvider).getMisObras();
  return data
      .map((e) => e as Map<String, dynamic>)
      .where((e) => e['obra'] != null)
      .map((e) => Obra.fromJson(e['obra'] as Map<String, dynamic>))
      .toList();
});

final historialAusenciasProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, perfilId) async {
    return ref.read(apiServiceProvider).getHistorialAusencias(perfilId);
  },
);

final diasSinParteProvider =
    FutureProvider.autoDispose<Map<String, AusenciaInfo>>((ref) async {
      final api = ref.read(apiServiceProvider);

      final results = await Future.wait([
        api.getDiasSinParte(),
        api.getFechaLibreActivos(),
      ]);

      final raw = results[0] as Map<String, dynamic>;
      final fechasHabilitadas = results[1] as Map<String, List<DateTime>>;

      return raw.map((uuid, value) {
        final info = value as Map<String, dynamic>;
        final infoConId = {'perfilId': uuid, ...info};

        final habilitadas = (fechasHabilitadas[uuid] ?? [])
            .map((dt) =>
                '${dt.day.toString().padLeft(2, '0')}/'
                '${dt.month.toString().padLeft(2, '0')}/'
                '${dt.year}')
            .toSet();

        return MapEntry(uuid, AusenciaInfo.fromJson(infoConId, habilitadas));
      });
    });
    
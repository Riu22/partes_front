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

      // Llamadas en paralelo
      final results = await Future.wait([
        api.getDiasSinParte(),
        api.getFechaLibreActivos(),
      ]);

      final raw = results[0] as Map<String, dynamic>;
      final fechasHabilitadas = results[1] as Map<String, List<DateTime>>;

      return raw.map((uuid, value) {
        final info = value as Map<String, dynamic>;
        final infoConId = {'perfilId': uuid, ...info};

        // Convertimos las fechas habilitadas de este perfil a strings "dd/MM/yyyy"
        // para que coincidan con el formato que usa diasSin
        final habilitadas = (fechasHabilitadas[uuid] ?? [])
            .map((dt) =>
                '${dt.day.toString().padLeft(2, '0')}/'
                '${dt.month.toString().padLeft(2, '0')}/'
                '${dt.year}')
            .toSet();

        return MapEntry(uuid, AusenciaInfo.fromJson(infoConId, habilitadas));
      });
    });

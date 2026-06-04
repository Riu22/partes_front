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

final historialAusenciasProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, perfilId) async {
    return ref.read(apiServiceProvider).getHistorialAusencias(perfilId);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// diasSinParteProvider — convertido a AsyncNotifierProvider para poder hacer
// actualizaciones optimistas sin parpadeos ni pantallas en blanco.
// ─────────────────────────────────────────────────────────────────────────────

final diasSinParteProvider = AsyncNotifierProvider.autoDispose<
    DiasSinParteNotifier, Map<String, AusenciaInfo>>(
  DiasSinParteNotifier.new,
);

class DiasSinParteNotifier
    extends AutoDisposeAsyncNotifier<Map<String, AusenciaInfo>> {
  @override
  Future<Map<String, AusenciaInfo>> build() async {
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
  }

  /// Elimina una ausencia del estado local de forma inmediata (optimista).
  /// Llama a esto ANTES de hacer la petición al servidor para que la UI
  /// no parpadee ni se quede en blanco.
  void eliminarAusenciaLocal(int ausenciaId) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = <String, AusenciaInfo>{};

    for (final entry in current.entries) {
      final info = entry.value;
      final nuevasAusencias =
          info.ausenciasActivas.where((a) => a.id != ausenciaId).toList();

      // Solo mantenemos el perfil si aún tiene algo que mostrar
      final tieneContenido = nuevasAusencias.isNotEmpty ||
          info.diasSin.isNotEmpty ||
          info.diasIncompletos.isNotEmpty;

      if (tieneContenido) {
        updated[entry.key] = AusenciaInfo(
          perfilId: info.perfilId,
          nombre: info.nombre,
          diasSin: info.diasSin,
          diasIncompletos: info.diasIncompletos,
          ausenciasActivas: nuevasAusencias,
          totalLaborables: info.totalLaborables,
          fechasHabilitadas: info.fechasHabilitadas,
        );
      }
    }

    // Actualizamos el estado sin pasar por loading — la UI no parpadea
    state = AsyncData(updated);
  }
}
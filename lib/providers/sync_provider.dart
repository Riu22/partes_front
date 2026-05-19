import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'auth_provider.dart';
import 'partes_provider.dart';

final offlineQueueProvider = Provider((ref) => OfflineQueueService());

final conectividadProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);
  yield* connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

final pendientesOfflineProvider = FutureProvider<int>((ref) async {
  final queue = ref.watch(offlineQueueProvider);
  return await queue.totalPendientes();
});

// ← AQUÍ, a nivel de archivo, no dentro de ninguna función
final listaOfflineProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  ref.watch(pendientesOfflineProvider);
  final queue = ref.read(offlineQueueProvider);
  final normales = await queue.getPartesOffline();
  final jefe = await queue.getPartesJefeOffline();
  return [
    ...normales.map((p) => {...p, '_tipo': 'normal'}),
    ...jefe.map((p) => {...p, '_tipo': 'jefe'}),
  ];
});

final syncProvider = Provider((ref) {
  ref.listen<AsyncValue<bool>>(conectividadProvider, (prev, next) {
    final tieneConexion = next.valueOrNull ?? false;
    final veniaDeSinConexion = !(prev?.valueOrNull ?? true);
    if (tieneConexion && veniaDeSinConexion) {
      _sincronizar(ref);
    }
  });

  final tieneRedAhora = ref.read(conectividadProvider).valueOrNull ?? false;
  if (tieneRedAhora) {
    _sincronizar(ref);
  }

  return null;
});

Future<void> _sincronizar(Ref ref) async {
  final queue = ref.read(offlineQueueProvider);
  final api = ref.read(apiServiceProvider);

  final partes = await queue.getPartesOffline();
  if (partes.isNotEmpty) {
    for (final parte in List.from(partes)) {
      try {
        await api.crearParte(parte);
        await queue.borrarParteNormal(parte);
        ref.invalidate(pendientesOfflineProvider);
        ref.invalidate(listaOfflineProvider); // ← también actualiza la UI
      } catch (e) {
        break;
      }
    }
    ref.invalidate(partesProvider);
  }

  final partesJefe = await queue.getPartesJefeOffline();
  if (partesJefe.isNotEmpty) {
    for (final parteJefe in List.from(partesJefe)) {
      try {
        await api.crearParteJefe(parteJefe);
        await queue.borrarParteJefe(parteJefe);
        ref.invalidate(pendientesOfflineProvider);
        ref.invalidate(listaOfflineProvider); // ← también actualiza la UI
      } catch (e) {
        break;
      }
    }
    ref.invalidate(partesJefeProvider);
  }

  final updates = await queue.getUpdatesOffline();
  if (updates.isNotEmpty) {
    for (final update in List.from(updates)) {
      try {
        final parteId = update['parteId'] as int;
        final data = Map<String, dynamic>.from(update)..remove('parteId');
        await api.updateParte(parteId, data);
        await queue.borrarUpdate(update);
        ref.invalidate(pendientesOfflineProvider);
      } catch (e) {
        break;
      }
    }
    ref.invalidate(partesProvider);
  }
}

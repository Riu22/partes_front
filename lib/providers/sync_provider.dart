import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'auth_provider.dart';
import 'partes_provider.dart';

// 1. Acceso al servicio de persistencia (SharedPreferences/SQLite)
final offlineQueueProvider = Provider((ref) => OfflineQueueService());

// 2. Monitor de conectividad en tiempo real
final conectividadProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  // Fix #5: emitir el estado real ANTES de escuchar cambios
  final initial = await connectivity.checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);

  yield* connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

// 3. Contador de partes que están "atrapados" en el móvil
final pendientesOfflineProvider = FutureProvider<int>((ref) async {
  final queue = ref.watch(offlineQueueProvider);
  return await queue.totalPendientes();
});

// 4. EL MOTOR DE SINCRONIZACIÓN
final syncProvider = Provider((ref) {
  // Escucha cambios de red (de No hay -> a Sí hay)
  ref.listen<AsyncValue<bool>>(conectividadProvider, (prev, next) {
    final tieneConexion = next.valueOrNull ?? false;
    final veniaDeSinConexion = !(prev?.valueOrNull ?? true);

    if (tieneConexion && veniaDeSinConexion) {
      _sincronizar(ref);
    }
  });

  // Disparo inicial: Si abres la app y ya hay red, intenta vaciar la cola
  final tieneRedAhora = ref.read(conectividadProvider).valueOrNull ?? false;
  if (tieneRedAhora) {
    _sincronizar(ref);
  }

  return null;
});

// 5. LÓGICA DE ENVÍO SEGURO (Uno a uno)
Future<void> _sincronizar(Ref ref) async {
  final queue = ref.read(offlineQueueProvider);
  final api = ref.read(apiServiceProvider);

  // --- Procesar Partes Normales ---
  final partes = await queue.getPartesOffline();
  if (partes.isNotEmpty) {
    for (final parte in List.from(partes)) {
      try {
        await api.crearParte(parte);
        await queue.borrarParteNormal(parte);
        // Fix #4: invalidar contador tras cada borrado, no solo al final
        ref.invalidate(pendientesOfflineProvider);
      } catch (e) {
        break;
      }
    }
    ref.invalidate(partesProvider);
  }

  // --- Procesar Partes de Jefe ---
  final partesJefe = await queue.getPartesJefeOffline();
  if (partesJefe.isNotEmpty) {
    for (final parteJefe in List.from(partesJefe)) {
      try {
        await api.crearParteJefe(parteJefe);
        await queue.borrarParteJefe(parteJefe);
        // Fix #4: invalidar contador tras cada borrado
        ref.invalidate(pendientesOfflineProvider);
      } catch (e) {
        break;
      }
    }
    ref.invalidate(partesJefeProvider);
  }

  // --- Procesar Updates (ediciones offline) ---
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

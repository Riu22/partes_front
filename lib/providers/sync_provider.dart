import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'auth_provider.dart';
import 'partes_provider.dart';

// 1. Acceso al servicio de persistencia (SharedPreferences/SQLite)
final offlineQueueProvider = Provider((ref) => OfflineQueueService());

// 2. Monitor de conectividad en tiempo real
final conectividadProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

// 3. Contador de partes que están "atrapados" en el móvil
final pendientesOfflineProvider = FutureProvider<int>((ref) async {
  final queue = ref.watch(offlineQueueProvider);
  return await queue.totalPendientes();
});

// 4. EL MOTOR DE SINCRONIZACIÓN (Corregido)
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
    // IMPORTANTE: Los enviamos de uno en uno
    for (final parte in List.from(partes)) {
      try {
        await api.crearParte(parte);
        // Si el servidor responde OK, lo borramos de la memoria del móvil
        await queue.borrarParteNormal(parte);
      } catch (e) {
        // Si falla este envío (ej: se volvió a caer la red), paramos el bucle
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
        // Borrado inmediato tras éxito
        await queue.borrarParteJefe(parteJefe);
      } catch (e) {
        break;
      }
    }
    ref.invalidate(partesJefeProvider);
  }

  // Actualizamos el contador de la interfaz
  ref.invalidate(pendientesOfflineProvider);
}

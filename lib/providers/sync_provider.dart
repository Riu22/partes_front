import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'auth_provider.dart';
import 'partes_provider.dart';

final offlineQueueProvider = Provider((ref) => OfflineQueueService());

// Estado de conectividad
final conectividadProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

// Cantidad de partes pendientes offline
final pendientesOfflineProvider = FutureProvider<int>((ref) async {
  final queue = ref.read(offlineQueueProvider);
  return await queue.totalPendientes();
});

// Sincronizador — se activa cuando vuelve la conexión
final syncProvider = Provider((ref) {
  ref.listen<AsyncValue<bool>>(conectividadProvider, (prev, next) async {
    final tieneConexion = next.valueOrNull ?? false;
    final prevConexion = prev?.valueOrNull ?? false;

    // Solo sincronizar cuando RECUPERA la conexión
    if (tieneConexion && !prevConexion) {
      await _sincronizar(ref);
    }
  });
  return null;
});

Future<void> _sincronizar(Ref ref) async {
  final queue = ref.read(offlineQueueProvider);
  final api = ref.read(apiServiceProvider);

  // Sincronizar partes normales
  final partes = await queue.getPartesOffline();
  if (partes.isNotEmpty) {
    bool todoOk = true;
    for (final parte in partes) {
      try {
        await api.crearParte(parte);
      } catch (_) {
        todoOk = false;
        break;
      }
    }
    if (todoOk) {
      await queue.limpiarPartesOffline();
      ref.invalidate(partesProvider);
    }
  }

  // Sincronizar partes de jefe
  final partesJefe = await queue.getPartesJefeOffline();
  if (partesJefe.isNotEmpty) {
    bool todoOk = true;
    for (final parte in partesJefe) {
      try {
        await api.crearParteJefe(parte);
      } catch (_) {
        todoOk = false;
        break;
      }
    }
    if (todoOk) {
      await queue.limpiarPartesJefeOffline();
      ref.invalidate(partesJefeProvider);
    }
  }

  ref.invalidate(pendientesOfflineProvider);
}

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'auth_provider.dart';
import 'partes_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

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
  final auth = ref.read(authServiceProvider);

  // Antes de sincronizar: asegura que el token es válido
  final tokenValido = await _asegurarToken(auth);
  if (!tokenValido) {
    // Token irrecuperable → forzar logout
    print('🔒 Token expirado e irrecuperable. Forzando logout...');
    ref.read(authProvider.notifier).logout();
    return;
  }

  // --- Partes Normales ---
  final partes = await queue.getPartesOffline();
  if (partes.isNotEmpty) {
    for (final parte in List.from(partes)) {
      try {
        await api.crearParte(parte);
        await queue.borrarParteNormal(parte);
        ref.invalidate(pendientesOfflineProvider);
      } catch (e) {
        break;
      }
    }
    ref.invalidate(partesProvider);
  }

  // --- Partes de Jefe ---
  final partesJefe = await queue.getPartesJefeOffline();
  if (partesJefe.isNotEmpty) {
    for (final parteJefe in List.from(partesJefe)) {
      try {
        await api.crearParteJefe(parteJefe);
        await queue.borrarParteJefe(parteJefe);
        ref.invalidate(pendientesOfflineProvider);
      } catch (e) {
        break;
      }
    }
    ref.invalidate(partesJefeProvider);
  }

  // --- Updates (ediciones offline) ---
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

/// Comprueba localmente si el JWT está expirado y refresca si hace falta.
/// Devuelve false solo si el refresh también falla (sesión muerta).
Future<bool> _asegurarToken(AuthService auth) async {
  final token = await auth.getToken();
  if (token == null) return false;

  if (auth.tokenExpirado(token)) {
    print('⏰ Token expirado. Intentando refrescar...');
    final nuevo = await auth.refrescarToken();
    return nuevo != null;
  }

  return true;
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'auth_provider.dart';
import 'partes_provider.dart';
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

// Motor de sincronización: se activa al recuperar la conexión o al iniciar la app.
// Se sincroniza con cualquier emisión true del stream, incluyendo la primera,
// eliminando la dependencia del ref.read inicial que podía devolver null.
final syncProvider = Provider((ref) {
  ref.listen<AsyncValue<bool>>(conectividadProvider, (prev, next) {
    final tieneConexion = next.valueOrNull ?? false;
    if (tieneConexion) {
      _sincronizar(ref);
    }
  });

  return null;
});

// Vacía la cola offline en orden: partes normales → partes jefe → updates.
// Distingue errores de cliente (4xx) de errores de red/servidor (5xx / timeout):
//   - 4xx: los datos son incorrectos y nunca se podrán subir → se descartan.
//   - Red / 5xx: error transitorio → se para la cola y se reintenta después.
Future<void> _sincronizar(Ref ref) async {
  final queue = ref.read(offlineQueueProvider);
  final api = ref.read(apiServiceProvider);
  final auth = ref.read(authServiceProvider);

  // Antes de sincronizar: asegura que el token es válido
  final tokenValido = await _asegurarToken(auth);
  if (!tokenValido) {
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
        ref.invalidate(listaOfflineProvider);
      } on Exception catch (e) {
        final status = _statusDeExcepcion(e);
        if (status != null && status >= 400 && status < 500) {
          // Datos incorrectos: este parte nunca se podrá subir, se descarta
          print('⚠️ Parte descartado por error $status: $e');
          await queue.borrarParteNormal(parte);
          ref.invalidate(pendientesOfflineProvider);
          ref.invalidate(listaOfflineProvider);
          continue;
        }
        // Error de red o 5xx: parar y reintentar después
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
        ref.invalidate(listaOfflineProvider);
      } on Exception catch (e) {
        final status = _statusDeExcepcion(e);
        if (status != null && status >= 400 && status < 500) {
          print('⚠️ Parte jefe descartado por error $status: $e');
          await queue.borrarParteJefe(parteJefe);
          ref.invalidate(pendientesOfflineProvider);
          ref.invalidate(listaOfflineProvider);
          continue;
        }
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
      } on Exception catch (e) {
        final status = _statusDeExcepcion(e);
        if (status != null && status >= 400 && status < 500) {
          print('⚠️ Update descartado por error $status: $e');
          await queue.borrarUpdate(update);
          ref.invalidate(pendientesOfflineProvider);
          continue;
        }
        break;
      }
    }
    ref.invalidate(partesProvider);
  }
}

/// Extrae el HTTP status code de una excepción si es un String con formato
/// "4xx" / "5xx" lanzado por ApiService, o null si es un error de red/timeout.
int? _statusDeExcepcion(Exception e) {
  final msg = e.toString();
  // DioException con respuesta lanza el data como String (ver ApiService).
  // Intentamos parsear el primer número de 3 dígitos que aparezca.
  final match = RegExp(r'\b([45]\d{2})\b').firstMatch(msg);
  if (match != null) return int.tryParse(match.group(1)!);
  return null;
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
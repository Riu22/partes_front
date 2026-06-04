/// Proveedor de conectividad y sincronización básica.
///
/// Monitorea si el teléfono tiene internet. Cuando se pierde
/// la conexión, guarda los partes en una cola local. Cuando
/// se recupera la conexión, envía automáticamente los partes
/// pendientes al servidor.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'auth_provider.dart';
import 'partes_provider.dart';
import '../services/auth_service.dart';

/// Provee el servicio de cola offline.
///
/// Este servicio guarda temporalmente los partes creados
/// sin conexión para enviarlos cuando haya internet.
final offlineQueueProvider = Provider((ref) => OfflineQueueService());

/// Provee un flujo continuo del estado de conexión a internet.
///
/// Emite `true` cuando hay conexión y `false` cuando no.
/// También revisa el estado inicial al abrir la app.
final conectividadProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  final initial = await connectivity.checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);

  yield* connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

/// Provee la cantidad de partes pendientes por sincronizar.
///
/// Cuenta cuántos partes están esperando en la cola offline
/// para ser enviados al servidor.
final pendientesOfflineProvider = FutureProvider<int>((ref) async {
  final queue = ref.watch(offlineQueueProvider);
  return await queue.totalPendientes();
});

/// Motor de sincronización que se activa al recuperar la conexión o al iniciar la app.
///
/// Escucha los cambios de conectividad. Cuando el teléfono pasa
/// de "sin internet" a "con internet", dispara la sincronización
/// de los partes pendientes. También sincroniza al abrir la app
/// si ya hay conexión.
final syncProvider = Provider((ref) {
  ref.listen<AsyncValue<bool>>(conectividadProvider, (prev, next) {
    final tieneConexion = next.valueOrNull ?? false;
    final veniaDeSinConexion = !(prev?.valueOrNull ?? true);

    // Solo sincroniza cuando se pasa de "sin red" a "con red"
    if (tieneConexion && veniaDeSinConexion) {
      _sincronizar(ref);
    }
  });

  // Intento inicial: si hay red al abrir la app, vacía la cola pendiente
  final tieneRedAhora = ref.read(conectividadProvider).valueOrNull ?? false;
  if (tieneRedAhora) {
    _sincronizar(ref);
  }

  return null;
});

/// Envía al servidor todos los partes pendientes guardados sin conexión.
///
/// Procesa primero los partes normales, luego los de jefe,
/// y por último las ediciones. Usa una copia de la lista
/// para evitar errores si la lista cambia mientras se procesa.
/// Si falla un parte, detiene el proceso (se reintentará después).
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
        break; // Si falla uno, para la cola (se reintentará después)
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

/// Revisa si el token de autenticación sigue siendo válido.
///
/// Si el token está vencido, intenta obtener uno nuevo usando
/// el token de actualización (refresh token).
/// Retorna `false` solo si el token no se puede renovar
/// (la sesión ya no es válida y hay que cerrarla).
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

import 'package:flutter/widgets.dart';
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

/// Provee la lista desempaquetada para poder pintarla en la interfaz si es necesario.
final listaOfflineProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(pendientesOfflineProvider);
  final queue = ref.read(offlineQueueProvider);
  
  final normales = await queue.getPartesOffline();
  final jefe = await queue.getPartesJefeOffline();
  
  return [
    ...normales.map((item) => {
          ...(item['data'] as Map<String, dynamic>),
          '_queue_id': item['queue_id'],
          '_tipo': 'normal',
        }),
    ...jefe.map((item) => {
          ...(item['data'] as Map<String, dynamic>),
          '_queue_id': item['queue_id'],
          '_tipo': 'jefe',
        }),
  ];
});

/// Estados auxiliares para controlar la UI de sincronización.
final estaSincronizandoProvider = StateProvider<bool>((ref) => false);
final syncErrorProvider = StateProvider<String?>((ref) => null);

/// Motor de sincronización reactivo y basado en eventos de ciclo de vida.
final syncProvider = Provider((ref) {
  
  // 1. ESCUCHAR CAMBIOS DE RED (Mientras la app está abierta)
  ref.listen<AsyncValue<bool>>(conectividadProvider, (prev, next) {
    final tieneConexion = next.valueOrNull ?? false;
    final veniaDeSinConexion = !(prev?.valueOrNull ?? true) || prev == null;

    if (tieneConexion && veniaDeSinConexion) {
      print('🌐 Red recuperada. Disparando sincronización...');
      _sincronizar(ref);
    }
  });

  // 2. DISPARADOR DE ARRANQUE EN FRÍO (Al abrir la app desde cero)
  Future.microtask(() {
    final tieneRedAhora = ref.read(conectividadProvider).valueOrNull ?? false;
    if (tieneRedAhora) {
      print('🚀 App abierta (Cold Start). Sincronizando cola inicial...');
      _sincronizar(ref);
    }
  });

  // 3. DISPARADOR DE CICLO DE VIDA (Al volver de segundo plano / desbloquear móvil)
  final lifecycleListener = AppLifecycleListener(
    onResume: () {
      final tieneRedAhora = ref.read(conectividadProvider).valueOrNull ?? false;
      if (tieneRedAhora) {
        print('📱 App recuperó el foco (onResume). Intentando sincronizar...');
        _sincronizar(ref);
      }
    },
  );

  ref.onDispose(() {
    lifecycleListener.dispose();
  });

  return null;
});

/// Vacía de forma secuencial y ordenada las colas pendientes.
Future<void> _sincronizar(Ref ref) async {
  if (ref.read(estaSincronizandoProvider)) return;

  ref.read(estaSincronizandoProvider.notifier).state = true;
  ref.read(syncErrorProvider.notifier).state = null;

  final queue = ref.read(offlineQueueProvider);
  final api   = ref.read(apiServiceProvider);
  final auth  = ref.read(authServiceProvider);

  try {
    final tokenValido = await _asegurarToken(auth);
    if (!tokenValido) {
      print('🔒 Token expirado e irrecuperable. Forzando logout...');
      ref.read(authProvider.notifier).logout();
      return;
    }

    // --- 1. Partes Normales ---
    final partesWrapped = await queue.getPartesOffline();
    for (final item in List.from(partesWrapped)) {
      final datosOriginales = Map<String, dynamic>.from(item['data']);
      datosOriginales['uuid_local'] = item['queue_id']; 

      try {
        await api.crearParte(datosOriginales);
        await queue.borrarParteNormal(item);
        _notificarCambio(ref);
      } on Exception catch (e) {
        if (_esErrorClienteDescartable(e)) {
          print('⚠️ Parte descartado por error crítico de cliente: $e');
          await queue.borrarParteNormal(item);
          _notificarCambio(ref);
          continue; 
        }
        
        final status = _statusDeExcepcion(e);
        if (status != null && status >= 500) {
          print('🚨 Error 5xx en servidor para este parte. Saltando para no bloquear la cola.');
          continue; // Evita el efecto tapón si el backend rompe con este JSON específico
        }
        
        ref.read(syncErrorProvider.notifier).state = _mensajeError(e);
        return; // Corte de red global, paramos toda la sincronización
      }
    }
    if (partesWrapped.isNotEmpty) ref.invalidate(partesProvider);

    // --- 2. Partes de Jefe ---
    final partesJefeWrapped = await queue.getPartesJefeOffline();
    for (final item in List.from(partesJefeWrapped)) {
      final datosOriginales = Map<String, dynamic>.from(item['data']);
      datosOriginales['uuid_local'] = item['queue_id'];

      try {
        await api.crearParteJefe(datosOriginales);
        await queue.borrarParteJefe(item);
        _notificarCambio(ref);
      } on Exception catch (e) {
        if (_esErrorClienteDescartable(e)) {
          print('⚠️ Parte de jefe descartado: $e');
          await queue.borrarParteJefe(item);
          _notificarCambio(ref);
          continue;
        }
        
        final status = _statusDeExcepcion(e);
        if (status != null && status >= 500) {
          print('🚨 Error 5xx en servidor (Jefe). Saltando elemento.');
          continue;
        }
        
        ref.read(syncErrorProvider.notifier).state = _mensajeError(e);
        return;
      }
    }
    if (partesJefeWrapped.isNotEmpty) ref.invalidate(partesJefeProvider);

    // --- 3. Updates (Ediciones) ---
    final updatesWrapped = await queue.getUpdatesOffline();
    for (final item in List.from(updatesWrapped)) {
      final datosOriginales = Map<String, dynamic>.from(item['data']);
      final parteId = datosOriginales['parteId'] as int;
      datosOriginales.remove('parteId');

      try {
        await api.updateParte(parteId, datosOriginales);
        await queue.borrarUpdate(item);
        _notificarCambio(ref);
      } on Exception catch (e) {
        if (_esErrorClienteDescartable(e)) {
          print('⚠️ Edición descartada: $e');
          await queue.borrarUpdate(item);
          _notificarCambio(ref);
          continue;
        }
        
        final status = _statusDeExcepcion(e);
        if (status != null && status >= 500) {
          print('🚨 Error 5xx en actualización de parte. Saltando elemento.');
          continue;
        }
        
        ref.read(syncErrorProvider.notifier).state = _mensajeError(e);
        return;
      }
    }
    if (updatesWrapped.isNotEmpty) ref.invalidate(partesProvider);

  } finally {
    ref.read(estaSincronizandoProvider.notifier).state = false;
  }
}

void _notificarCambio(Ref ref) {
  ref.invalidate(pendientesOfflineProvider);
}

bool _esErrorClienteDescartable(Exception e) {
  final status = _statusDeExcepcion(e);
  return status != null && status >= 400 && status < 500 && status != 401 && status != 429;
}

int? _statusDeExcepcion(Exception e) {
  final msg = e.toString();
  final match = RegExp(r'\b([45]\d{2})\b').firstMatch(msg);
  if (match != null) return int.tryParse(match.group(1)!);
  return null;
}

String _mensajeError(Exception e) {
  final msg = e.toString();
  final limpio = msg
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^DioException\s*\[.*?\]:\s*'), '')
      .trim();
  return limpio.isNotEmpty ? limpio : 'Error de red al sincronizar.';
}

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
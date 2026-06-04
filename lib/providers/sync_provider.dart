/// Proveedor de sincronización avanzado.
///
/// Es la versión más completa del motor de sincronización.
/// Además de sincronizar cuando se recupera la conexión,
/// también sincroniza al abrir la app y al volver de segundo plano.
/// Maneja errores de servidor de forma inteligente:
/// si un parte da error 4xx (error del cliente) lo descarta,
/// si da error 5xx (error del servidor) lo salta,
/// y si es error de red, detiene toda la sincronización.
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';
import 'auth_provider.dart';
import 'partes_provider.dart';
import '../services/auth_service.dart';

/// Provee el servicio de cola offline.
///
/// Guarda los partes creados sin conexión para enviarlos
/// cuando haya internet disponible.
final offlineQueueProvider = Provider((ref) => OfflineQueueService());

/// Provee un flujo continuo del estado de conexión a internet.
///
/// Emite `true` cuando hay conexión y `false` cuando no.
/// Se usa para saber cuándo sincronizar los datos pendientes.
final conectividadProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  
  final initial = await connectivity.checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);

  yield* connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

/// Provee la cantidad total de partes pendientes por sincronizar.
///
/// Cuenta tanto partes normales como partes de jefe
/// que están esperando en la cola offline.
final pendientesOfflineProvider = FutureProvider<int>((ref) async {
  final queue = ref.watch(offlineQueueProvider);
  return await queue.totalPendientes();
});

/// Provee la lista completa de partes pendientes para mostrarlos en la interfaz.
///
/// Junta los partes normales y los de jefe en una sola lista,
/// agregando el tipo y el identificador de cada uno para
/// poder identificarlos al mostrarlos en pantalla.
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

/// Indica si la app está sincronizando datos en este momento.
///
/// Se usa para mostrar un indicador de carga en la interfaz.
final estaSincronizandoProvider = StateProvider<bool>((ref) => false);

/// Guarda el último error ocurrido durante la sincronización.
///
/// Si hay un error, se muestra al usuario en la interfaz.
/// Se limpia automáticamente al empezar una nueva sincronización.
final syncErrorProvider = StateProvider<String?>((ref) => null);

/// Motor de sincronización avanzado.
///
/// Dispara la sincronización en tres situaciones:
/// 1. Cuando se recupera la conexión a internet.
/// 2. Al abrir la app desde cero (cold start).
/// 3. Al volver de segundo plano o desbloquear el móvil (onResume).
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

/// Envía al servidor todos los partes pendientes de forma ordenada.
///
/// Procesa primero los partes normales, luego los de jefe,
/// y por último las ediciones. Si un parte da error 4xx
/// (error del cliente, ej. datos inválidos) lo descarta.
/// Si da error 5xx (error del servidor) lo salta y sigue.
/// Si es error de red, detiene todo el proceso.
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

/// Actualiza el contador de pendientes en la interfaz.
///
/// Invalida el proveedor de pendientes para que se vuelva
/// a calcular y la interfaz muestre el número actualizado.
void _notificarCambio(Ref ref) {
  ref.invalidate(pendientesOfflineProvider);
}

/// Revisa si un error es del tipo "error del cliente" que se puede descartar.
///
/// Los errores 4xx (excepto 401 no autorizado y 429 muchos intentos)
/// indican que el problema es del lado del cliente (ej. datos inválidos)
/// y se pueden descartar porque el servidor nunca los aceptará.
/// Retorna `true` si el error se puede ignorar.
bool _esErrorClienteDescartable(Exception e) {
  final status = _statusDeExcepcion(e);
  return status != null && status >= 400 && status < 500 && status != 401 && status != 429;
}

/// Extrae el código de estado HTTP de un mensaje de error.
///
/// Busca números como 400, 401, 500, 502, etc. dentro del texto
/// del error. Retorna el código numérico o `null` si no encuentra
/// ninguno (probablemente es un error de red).
int? _statusDeExcepcion(Exception e) {
  final msg = e.toString();
  final match = RegExp(r'\b([45]\d{2})\b').firstMatch(msg);
  if (match != null) return int.tryParse(match.group(1)!);
  return null;
}

/// Convierte una excepción en un mensaje de error legible para el usuario.
///
/// Limpia el texto del error quitando prefijos técnicos como
/// "Exception:" o "DioException[xxx]:" para mostrar solo
/// el mensaje útil. Si no se puede extraer nada, devuelve
/// un mensaje genérico.
String _mensajeError(Exception e) {
  final msg = e.toString();
  final limpio = msg
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^DioException\s*\[.*?\]:\s*'), '')
      .trim();
  return limpio.isNotEmpty ? limpio : 'Error de red al sincronizar.';
}

/// Revisa si el token de autenticación sigue siendo válido y lo renueva si es necesario.
///
/// Si el token está vencido, intenta obtener uno nuevo.
/// Retorna `false` solo si no se puede renovar (la sesión expiró).
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
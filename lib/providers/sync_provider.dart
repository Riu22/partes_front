/// =============================================================================
/// PROVEEDOR DE SINCRONIZACION AVANZADO (sync_provider.dart)
/// =============================================================================
///
/// QUE ES UN PROVIDER (Riverpod)?
/// -----------------------------------------------------------------------------
/// Un Provider es como un altavoz central. Gestiona datos (estado) y notifica
/// automaticamente a todas las pantallas que estan escuchando. Cuando el dato
/// cambia, las pantallas se actualizan solas.
///
/// CONCEPTOS FUNDAMENTALES DE RIVERPOD:
///
///   ref.watch(provider)
///     Suscribe al widget al provider. Se reconstruye cuando cambia.
///
///   ref.read(provider)
///     Lee el valor una vez sin suscribirse.
///
///   ref.listen(provider, callback)
///     Escucha cambios SIN reconstruir el widget. Ideal para efectos
///     secundarios como sincronizacion. callback: (prev, next).
///
///   ref.invalidate(provider)
///     Marca provider como desactualizado. Se recargara al acceder.
///
///   .valueOrNull (AsyncValue.valueOrNull)
///     Obtiene el valor actual, o null si loading/error.
///
///   ref.read(provider.notifier).logout()
///     Accede al notifier para llamar metodos.
///
///   ref.onDispose(callback)
///     Callback que se ejecuta cuando el provider se destruye. Sirve
///     para limpiar recursos (sockets, listeners, etc.).
///
///   Provider<T>
///     Provider sincrono simple. Crea un valor y lo reutiliza.
///
///   StreamProvider<T>
///     Provider que escucha un Stream. Emite valores continuamente.
///
///   FutureProvider<T>
///     Provider asincrono que se ejecuta una vez.
///
///   StateProvider<T>
///     Provider con estado sincrono mutable. Se modifica asignando
///     ref.read(provider.notifier).state = nuevoValor.
///     Sirve para banderas y valores simples (bool, String, int).
///     Ej: StateProvider<bool> para "esta sincronizando".
///
/// SINCRONIZACION AVANZADA (OFFLINE / ONLINE):
///
///   DISPARADORES (cuando se activa la sincronizacion):
///   1. Cambio de red: cuando el telefono pasa de "sin internet" a
///      "con internet" mientras la app esta abierta.
///   2. Cold start: al abrir la app desde cero.
///   3. OnResume: al volver de segundo plano o desbloquear el movil.
///
///   MANEJO DE ERRORES (mas inteligente que la version basica):
///   - Error 4xx (cliente): el parte se DESCARTA (se borra de la cola).
///     El servidor nunca aceptara esos datos, no tiene sentido reintentar.
///     Excepcion: 401 (no autorizado) y 429 (too many requests) NO se
///     descartan.
///   - Error 5xx (servidor): el parte se SALTA (no se borra de la cola).
///     Se reintentara en la proxima sincronizacion. No bloquea la cola.
///   - Error de red (sin conexion): se DETIENE toda la sincronizacion.
///     Se reintentara cuando se recupere la conexion.
///
///   INDICADORES DE ESTADO:
///   - estaSincronizandoProvider: true mientras sincroniza.
///   - syncErrorProvider: contiene el ultimo error, null si todo ok.
///
/// QUE HACE ESTE ARCHIVO:
///   1. offlineQueueProvider: servicio para cola offline.
///   2. conectividadProvider: monitoreo de red en tiempo real.
///   3. pendientesOfflineProvider: contador de pendientes.
///   4. listaOfflineProvider: lista completa de pendientes para la UI.
///   5. estaSincronizandoProvider: bandera de sincronizacion activa.
///   6. syncErrorProvider: ultimo error de sincronizacion.
///   7. syncProvider: motor principal de sincronizacion.
///   8. Funciones auxiliares: _sincronizar, _asegurarToken, etc.
/// =============================================================================

/// Proveedor de sincronizacion avanzado.
///
/// Es la version mas completa del motor de sincronizacion.
/// Ademas de sincronizar cuando se recupera la conexion,
/// tambien sincroniza al abrir la app y al volver de segundo plano.
/// Maneja errores de servidor de forma inteligente:
/// si un parte da error 4xx (error del cliente) lo descarta,
/// si da error 5xx (error del servidor) lo salta,
/// y si es error de red, detiene toda la sincronizacion.
import 'package:flutter/widgets.dart';
// flutter/widgets: proporciona AppLifecycleListener para detectar cuando
// la app vuelve de segundo plano (onResume).

import 'package:connectivity_plus/connectivity_plus.dart';
// connectivity_plus: detecta cambios en la conexion de red.

import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod: gestion de estado con providers, ref, etc.

import '../services/offline_queue_service.dart';
// OfflineQueueService: servicio de cola offline (partes pendientes).

import 'auth_provider.dart';
// auth_provider: para acceder a authProvider.notifier y servicios.

import 'partes_provider.dart';
// partes_provider: para invalidar y recargar datos despues de sincronizar.

import '../services/auth_service.dart';
// AuthService: para manejo de tokens de autenticacion.

/// Provee el servicio de cola offline.
///
/// Guarda los partes creados sin conexion en almacenamiento local
/// para enviarlos cuando haya internet disponible.
final offlineQueueProvider = Provider((ref) => OfflineQueueService());

/// Provee un flujo continuo del estado de conexion a internet.
///
/// Emite true cuando hay conexion, false cuando no.
/// Se usa para saber cuando sincronizar los datos pendientes.
///
/// Es un StreamProvider porque la conectividad cambia en el tiempo
/// (el usuario puede perder y recuperar la red en cualquier momento).
final conectividadProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  // Emitir estado inicial de la red.
  final initial = await connectivity.checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);

  // Escuchar y emitir cambios futuros en la red.
  yield* connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

/// Provee la cantidad total de partes pendientes por sincronizar.
///
/// Cuenta partes normales + partes de jefe que estan en la cola offline.
///
/// Se refresca automaticamente porque usa ref.watch(offlineQueueProvider)
/// y se invalida cada vez que se envia o borra un parte.
final pendientesOfflineProvider = FutureProvider<int>((ref) async {
  final queue = ref.watch(offlineQueueProvider);
  return await queue.totalPendientes();
});

/// Provee la lista completa de partes pendientes para mostrarlos en la UI.
///
/// Junta los partes normales y los de jefe en una sola lista, agregando
/// campos adicionales para identificarlos:
///   - _queue_id: identificador unico en la cola offline.
///   - _tipo: 'normal' o 'jefe' para distinguir el origen.
///
/// ref.watch(pendientesOfflineProvider) al inicio hace que este provider
/// se refresque automaticamente cuando el contador de pendientes cambia.
final listaOfflineProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Dependencia: cuando pendientesOfflineProvider se invalida,
  // este provider tambien se invalida y se recarga.
  ref.watch(pendientesOfflineProvider);

  final queue = ref.read(offlineQueueProvider);

  // Obtener partes normales y de jefe de la cola offline.
  final normales = await queue.getPartesOffline();
  final jefe = await queue.getPartesJefeOffline();

  // Combinar ambas listas en una sola, agregando metadatos.
  return [
    // Mapear cada parte normal agregando _queue_id y _tipo.
    ...normales.map((item) => {
          // Extraer los datos originales del parte.
          ...(item['data'] as Map<String, dynamic>),
          // Agregar metadatos para identificar el item en la UI.
          '_queue_id': item['queue_id'],
          '_tipo': 'normal',
        }),
    // Mapear cada parte de jefe, misma estructura.
    ...jefe.map((item) => {
          ...(item['data'] as Map<String, dynamic>),
          '_queue_id': item['queue_id'],
          '_tipo': 'jefe',
        }),
  ];
});

/// Indica si la app esta sincronizando datos en este momento.
///
/// StateProvider<bool>: estado sincrono simple.
/// Se pone en true al empezar la sincronizacion y en false al terminar.
/// La UI puede leerlo para mostrar/ocultar un indicador de progreso.
final estaSincronizandoProvider = StateProvider<bool>((ref) => false);

/// Guarda el ultimo error ocurrido durante la sincronizacion.
///
/// StateProvider<String?>: puede ser null (sin error) o un String
/// con la descripcion del error. Se limpia al empezar una nueva
/// sincronizacion. La UI lo usa para mostrar mensajes de error.
final syncErrorProvider = StateProvider<String?>((ref) => null);

/// Motor de sincronizacion avanzado.
///
/// Es un Provider que retorna null (no provee datos) pero ejecuta
/// efectos secundarios: escucha la conectividad y dispara la
/// sincronizacion en los momentos adecuados.
///
/// DISPARADORES:
///   1. Cambio de red (sin internet -> con internet).
///   2. Cold start (app abierta desde cero).
///   3. OnResume (app vuelve de segundo plano o se desbloquea).
///
/// ref.onDispose() se usa para limpiar el AppLifecycleListener
/// cuando el provider se destruye.
final syncProvider = Provider((ref) {

  // --- 1. ESCUCHAR CAMBIOS DE RED ---
  // Mientras la app esta abierta y en primer plano, escucha
  // cambios en la conectividad. Cuando se recupera la red,
  // dispara la sincronizacion.
  ref.listen<AsyncValue<bool>>(conectividadProvider, (prev, next) {
    // Obtener el estado actual de conexion.
    final tieneConexion = next.valueOrNull ?? false;

    // Detectar si se viene de un estado sin conexion.
    // prev == null significa que es la primera emision (no contar).
    final veniaDeSinConexion = !(prev?.valueOrNull ?? true) || prev == null;

    // Solo sincronizar en la transicion "sin red -> con red".
    if (tieneConexion && veniaDeSinConexion) {
      print(' Red recuperada. Disparando sincronización...');
      _sincronizar(ref);
    }
  });

  // --- 2. DISPARADOR DE ARRANQUE EN FRIO (COLD START) ---
  // Al abrir la app desde cero (o al crear este provider),
  // si hay conexion de red, sincronizar inmediatamente.
  // Future.microtask pospone la ejecucion para que el widget tree
  // termine de construirse antes de iniciar la sincronizacion.
  Future.microtask(() {
    final tieneRedAhora = ref.read(conectividadProvider).valueOrNull ?? false;
    if (tieneRedAhora) {
      print(' App abierta (Cold Start). Sincronizando cola inicial...');
      _sincronizar(ref);
    }
  });

  // --- 3. DISPARADOR DE CICLO DE VIDA (ONRESUME) ---
  // Cuando la app vuelve de segundo plano (el usuario abrio otra app
  // y vuelve, o desbloquea el movil), verificar si hay red y sincronizar.
  // AppLifecycleListener es un widget de Flutter que detecta cambios
  // en el ciclo de vida de la app (onResume, onPause, etc.).
  final lifecycleListener = AppLifecycleListener(
    onResume: () {
      // El usuario volvio a la app (o desbloqueo el telefono).
      final tieneRedAhora = ref.read(conectividadProvider).valueOrNull ?? false;
      if (tieneRedAhora) {
        print(' App recuperó el foco (onResume). Intentando sincronizar...');
        _sincronizar(ref);
      }
    },
  );

  // Limpiar el listener cuando el provider se destruya.
  // ref.onDispose() se ejecuta automaticamente cuando el provider
  // ya no es necesario (ej. la app se cierra).
  ref.onDispose(() {
    lifecycleListener.dispose();
  });

  // El provider retorna null porque solo ejecuta side effects.
  return null;
});

/// Envia al servidor todos los partes pendientes de forma ordenada e inteligente.
///
/// ORDEN DE PROCESAMIENTO:
///   1. Partes normales (creados por el trabajador).
///   2. Partes de jefe (creados por el supervisor).
///   3. Ediciones (updates) a partes existentes.
///
/// MANEJO DE ERRORES:
///   - Error 4xx (cliente): descarta el parte (lo borra de la cola).
///     El servidor nunca aceptara datos invalidos.
///     Excepcion: 401 (no autorizado) y 429 (too many requests).
///   - Error 5xx (servidor): salta el parte (NO lo borra).
///     El servidor fallo temporalmente. Se reintentara despues.
///   - Error de red: DETIENE toda la sincronizacion.
///     No tiene sentido seguir si no hay conexion.
///
/// SEGURIDAD:
///   - Verifica que el token JWT sea valido antes de empezar.
///   - Si el token no se puede renovar, fuerza logout.
///
/// UI:
///   - Pone estaSincronizandoProvider en true mientras procesa.
///   - Si hay error, lo guarda en syncErrorProvider.
///   - Invalida pendientesOfflineProvider despues de cada item.
///   - Invalida partesProvider / partesJefeProvider al final.
Future<void> _sincronizar(Ref ref) async {
  // Prevenir sincronizaciones simultaneas.
  // Si ya se esta sincronizando, salir inmediatamente.
  if (ref.read(estaSincronizandoProvider)) return;

  // Marcar que la sincronizacion empezo.
  ref.read(estaSincronizandoProvider.notifier).state = true;
  // Limpiar errores anteriores.
  ref.read(syncErrorProvider.notifier).state = null;

  // Obtener servicios necesarios.
  final queue = ref.read(offlineQueueProvider);
  final api   = ref.read(apiServiceProvider);
  final auth  = ref.read(authServiceProvider);

  try {
    // Verificar validez del token JWT antes de empezar.
    final tokenValido = await _asegurarToken(auth);
    if (!tokenValido) {
      // Token expirado y no se pudo renovar -> forzar logout.
      print(' Token expirado e irrecuperable. Forzando logout...');
      ref.read(authProvider.notifier).logout();
      return;
    }

    // --- 1. PARTES NORMALES ---
    final partesWrapped = await queue.getPartesOffline();
    for (final item in List.from(partesWrapped)) {
      // Hacer una copia mutable de los datos originales.
      final datosOriginales = Map<String, dynamic>.from(item['data']);
      // Agregar el identificador unico local para tracking en el servidor.
      datosOriginales['uuid_local'] = item['queue_id'];

      try {
        // Enviar parte al servidor (POST /api/partes/).
        await api.crearParte(datosOriginales);
        // Si el servidor acepto, borrar de la cola offline.
        await queue.borrarParteNormal(item);
        _notificarCambio(ref);
      } on Exception catch (e) {
        // --- ERROR 4xx (cliente): datos invalidos, descartar ---
        if (_esErrorClienteDescartable(e)) {
          print(' Parte descartado por error crítico de cliente: $e');
          await queue.borrarParteNormal(item);
          _notificarCambio(ref);
          continue; // Seguir con el siguiente parte.
        }

        // --- ERROR 5xx (servidor): fallo temporal, saltar ---
        final status = _statusDeExcepcion(e);
        if (status != null && status >= 500) {
          print(' Error 5xx en servidor para este parte. Saltando para no bloquear la cola.');
          continue; // No borrar, se reintentara despues.
        }

        // --- ERROR DE RED: detener toda la sincronizacion ---
        // No se pudo determinar el codigo HTTP: probablemente es error
        // de conexion (timeout, DNS, socket). Guardar el error y parar.
        ref.read(syncErrorProvider.notifier).state = _mensajeError(e);
        return; // Corte de red global.
      }
    }
    // Si habia partes pendientes, recargar la lista de partes.
    if (partesWrapped.isNotEmpty) ref.invalidate(partesProvider);

    // --- 2. PARTES DE JEFE ---
    // Misma logica que partes normales pero para el tipo jefe.
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
          print(' Parte de jefe descartado: $e');
          await queue.borrarParteJefe(item);
          _notificarCambio(ref);
          continue;
        }

        final status = _statusDeExcepcion(e);
        if (status != null && status >= 500) {
          print(' Error 5xx en servidor (Jefe). Saltando elemento.');
          continue;
        }

        ref.read(syncErrorProvider.notifier).state = _mensajeError(e);
        return;
      }
    }
    if (partesJefeWrapped.isNotEmpty) ref.invalidate(partesJefeProvider);

    // --- 3. UPDATES (EDICIONES) ---
    // Procesar modificaciones a partes existentes hechas sin conexion.
    final updatesWrapped = await queue.getUpdatesOffline();
    for (final item in List.from(updatesWrapped)) {
      final datosOriginales = Map<String, dynamic>.from(item['data']);
      // Extraer el ID del parte que se quiere modificar.
      final parteId = datosOriginales['parteId'] as int;
      // Quitar el campo parteId porque no se envia al servidor.
      datosOriginales.remove('parteId');

      try {
        // Enviar la actualizacion al servidor (PUT /api/partes/:id/).
        await api.updateParte(parteId, datosOriginales);
        await queue.borrarUpdate(item);
        _notificarCambio(ref);
      } on Exception catch (e) {
        if (_esErrorClienteDescartable(e)) {
          print(' Edición descartada: $e');
          await queue.borrarUpdate(item);
          _notificarCambio(ref);
          continue;
        }

        final status = _statusDeExcepcion(e);
        if (status != null && status >= 500) {
          print(' Error 5xx en actualización de parte. Saltando elemento.');
          continue;
        }

        ref.read(syncErrorProvider.notifier).state = _mensajeError(e);
        return;
      }
    }
    if (updatesWrapped.isNotEmpty) ref.invalidate(partesProvider);

  } finally {
    // Este bloque se ejecuta SIEMPRE, haya error o no.
    // Asegura que la bandera de sincronizacion se apague incluso
    // si ocurre una excepcion inesperada.
    ref.read(estaSincronizandoProvider.notifier).state = false;
  }
}

/// Actualiza el contador de pendientes en la interfaz.
///
/// Invalida pendientesOfflineProvider para que se recalcule y la UI
/// muestre el numero actualizado de partes pendientes.
void _notificarCambio(Ref ref) {
  ref.invalidate(pendientesOfflineProvider);
}

/// Revisa si un error es del tipo "error del cliente" descartable.
///
/// Los errores HTTP 4xx significan que el problema es del cliente
/// (datos invalidos, formato incorrecto, etc.). El servidor nunca
/// aceptara esos datos, aunque se reintente mil veces.
///
/// Reglas:
///   - 400-499: error del cliente -> descartable.
///   - 401: no autorizado -> NO descartable (puede ser token expirado).
///   - 429: too many requests -> NO descartable (reintentar despues).
///
/// Retorna true si el error se puede descartar (borrar de la cola).
bool _esErrorClienteDescartable(Exception e) {
  final status = _statusDeExcepcion(e);
  return status != null && status >= 400 && status < 500 && status != 401 && status != 429;
}

/// Extrae el codigo de estado HTTP de un mensaje de error.
///
/// Busca numeros de 3 digitos que empiecen con 4 o 5 (ej. 400, 401,
/// 500, 502, etc.) dentro del texto del error.
///
/// Retorna:
///   - int: el codigo HTTP si se encuentra.
///   - null: si no hay codigo (probablemente error de red sin HTTP).
int? _statusDeExcepcion(Exception e) {
  final msg = e.toString();
  // Buscar patron de 3 digitos que empiece con 4 o 5.
  // \b es un límite de palabra, [45] es 4 o 5, \d{2} son 2 digitos.
  final match = RegExp(r'\b([45]\d{2})\b').firstMatch(msg);
  if (match != null) return int.tryParse(match.group(1)!);
  return null;
}

/// Convierte una excepcion en un mensaje de error legible para el usuario.
///
/// Limpia el texto del error eliminando prefijos tecnicos:
///   - "Exception: " -> ""
///   - "DioException[xxx]: " -> ""
///
/// Retorna el mensaje limpio, o un texto generico si no se puede extraer.
String _mensajeError(Exception e) {
  final msg = e.toString();
  // Eliminar prefijos tecnicos comunes.
  final limpio = msg
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^DioException\s*\[.*?\]:\s*'), '')
      .trim();
  return limpio.isNotEmpty ? limpio : 'Error de red al sincronizar.';
}

/// Revisa si el token de autenticacion sigue siendo valido y lo renueva si es necesario.
///
/// Pasos:
///   1. Obtener el token JWT guardado.
///   2. Si no hay token, retornar false.
///   3. Si el token esta expirado, intentar renovar con refresh_token.
///   4. Retornar true si hay token valido, false si no se pudo renovar.
Future<bool> _asegurarToken(AuthService auth) async {
  final token = await auth.getToken();
  if (token == null) return false;

  // Verificar expiracion del token JWT.
  if (auth.tokenExpirado(token)) {
    print(' Token expirado. Intentando refrescar...');
    // Solicitar nuevo token usando el refresh_token almacenado.
    final nuevo = await auth.refrescarToken();
    return nuevo != null;
  }

  // Token aun valido.
  return true;
}

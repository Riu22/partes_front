/// =============================================================================
/// PROVEEDOR DE CONECTIVIDAD Y SINCRONIZACION BASICA (connectivity_provider.dart)
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
///     Escucha cambios en un provider SIN reconstruir el widget.
///     Se usa para efectos secundarios (como sincronizar datos).
///     El callback recibe (valorAnterior, valorNuevo).
///
///   ref.invalidate(provider)
///     Marca al provider como desactualizado. Se recargara al acceder.
///
///   .valueOrNull (AsyncValue.valueOrNull)
///     Obtiene el valor actual del AsyncValue, o null si loading/error.
///
///   ref.read(provider.notifier).logout()
///     Accede al notifier de un provider para llamar metodos.
///
///   Provider<T>
///     Provider sincrono simple. Crea un objeto/valor una vez.
///
///   StreamProvider<T>
///     Provider que escucha un Stream (flujo continuo de datos).
///     Emite nuevos valores cada vez que el stream emite.
///     Ideal para conectividad, sensores, GPS, etc.
///
///   FutureProvider<T>
///     Provider asincrono que se ejecuta una vez. Ideal para APIs.
///
/// OFFLINE / ONLINE (SINCRONIZACION BASICA):
///
///   Esta es la version BASICA del motor de sincronizacion.
///   La version AVANZADA esta en sync_provider.dart.
///
///   FLUJO COMPLETO:
///   1. conectividadProvider monitorea internet constantemente.
///   2. Cuando hay internet -> emite true. Cuando no -> emite false.
///   3. syncProvider escucha estos cambios con ref.listen().
///   4. Cuando se pasa de "sin internet" a "con internet":
///      a. Verifica que el token JWT sea valido (lo renueva si es necesario).
///      b. Procesa partes normales pendientes (cola offline).
///      c. Procesa partes de jefe pendientes.
///      d. Procesa ediciones (updates) pendientes.
///      e. Invalida los providers de partes para que recarguen datos frescos.
///   5. Si el token no se puede renovar, fuerza logout.
///   6. Si un elemento falla, detiene el proceso (se reintentara despues).
///
/// DIFERENCIAS CON LA VERSION AVANZADA (sync_provider.dart):
///   - Esta version es mas simple: si falla un parte, DETIENE todo.
///   - La version avanzada maneja errores 4xx (descarta) y 5xx (salta).
///   - La version avanzada se activa tambien al volver de segundo plano.
///
/// QUE HACE ESTE ARCHIVO:
///   1. offlineQueueProvider: servicio que guarda partes offline en cola.
///   2. conectividadProvider: flujo continuo del estado de internet.
///   3. pendientesOfflineProvider: cuenta de partes pendientes por enviar.
///   4. syncProvider: motor que sincroniza cuando se recupera la red.
/// =============================================================================

/// Proveedor de conectividad y sincronizacion basica.
///
/// Monitorea si el telefono tiene internet. Cuando se pierde
/// la conexion, guarda los partes en una cola local. Cuando
/// se recupera la conexion, envia automaticamente los partes
/// pendientes al servidor.
import 'package:connectivity_plus/connectivity_plus.dart';
// connectivity_plus: detecta cambios en la conexion de red (wifi, datos, etc.).

import 'package:flutter_riverpod/flutter_riverpod.dart';
// flutter_riverpod: gestion de estado con providers, ref, StreamProvider, etc.

import '../services/offline_queue_service.dart';
// OfflineQueueService: servicio que guarda en SQLite/Hive los partes
// creados sin conexion para enviarlos cuando haya internet.

import 'auth_provider.dart';
// auth_provider: necesario para acceder a authProvider.notifier (logout)
// y a apiServiceProvider (API) y authServiceProvider (tokens).

import 'partes_provider.dart';
// partes_provider: necesario para invalidar partesProvider y
// partesJefeProvider despues de sincronizar, forzando recarga.

import '../services/auth_service.dart';
// AuthService: necesario para revisar/renovar tokens de autenticacion.

/// Provee el servicio de cola offline.
///
/// Este servicio guarda temporalmente los partes creados sin conexion
/// en almacenamiento local del telefono. Cuando se recupera la conexion,
/// el syncProvider los envia al servidor.
///
/// Es un Provider simple (no Future ni Stream) porque OfflineQueueService
/// es una clase que se crea una vez y sus metodos se llaman directamente.
///
/// Metodos principales:
///   - guardarParteOffline(data):  guarda un parte nuevo en la cola.
///   - getPartesOffline():         obtiene todos los partes pendientes.
///   - borrarParteNormal(item):    elimina un parte ya enviado.
///   - totalPendientes():          cuenta cuantos partes esperan.
final offlineQueueProvider = Provider((ref) => OfflineQueueService());

/// Provee un flujo continuo del estado de conexion a internet.
///
/// Es un StreamProvider que:
///   1. Emite el estado inicial al suscribirse (hay red o no).
///   2. Escucha cambios en la conectividad del telefono.
///   3. Emite true cuando hay conexion, false cuando no.
///
/// Uso tipico:
///   final conexionAsync = ref.watch(conectividadProvider);
///   final hayRed = conexionAsync.valueOrNull ?? false;
///
/// NOTA: async* significa que es una funcion generadora asincrona.
/// Usa yield para emitir valores, yield* para delegar a otro stream.
final conectividadProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  // Emitir el estado inicial de la red al abrir la app.
  // checkConnectivity() devuelve una lista de ConnectivityResult.
  // Si alguno no es none, hay conexion.
  final initial = await connectivity.checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);

  // Escuchar cambios en la conectividad en tiempo real.
  // onConnectivityChanged emite cada vez que el estado de red cambia.
  // map() transforma cada lista de resultados a un booleano.
  // yield* delega la emision al stream resultante.
  yield* connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

/// Provee la cantidad de partes pendientes por sincronizar.
///
/// Cuenta cuantos partes (normales + jefe) estan esperando en la cola
/// offline para ser enviados al servidor.
///
/// Se usa en la UI para mostrar un badge o contador de pendientes.
/// Ejemplo: "Tienes 3 partes pendientes por sincronizar".
///
/// ref.invalidate(pendientesOfflineProvider) se llama despues de
/// enviar cada parte, para que el contador se actualice en la UI.
final pendientesOfflineProvider = FutureProvider<int>((ref) async {
  // Obtener el servicio de cola offline.
  final queue = ref.watch(offlineQueueProvider);
  // Llamar al metodo que cuenta los pendientes.
  return await queue.totalPendientes();
});

/// Motor de sincronizacion que se activa al recuperar la conexion o al iniciar la app.
///
/// Es un Provider simple que retorna null. Su proposito NO es proveer datos,
/// sino EJECUTAR EFECTOS SECUNDARIOS (side effects) cuando la conectividad
/// cambia. Usa ref.listen() para escuchar cambios sin reconstruir widgets.
///
/// MOMENTOS EN QUE SE ACTIVA:
///   1. Cuando el telefono pasa de "sin internet" a "con internet".
///   2. Al iniciar la app, si ya hay conexion de red.
///
/// QUE HACE CUANDO SE ACTIVA:
///   Llama a _sincronizar() que procesa la cola offline completa.
final syncProvider = Provider((ref) {
  // Escuchar cambios en el estado de conectividad usando ref.listen().
  // A diferencia de ref.watch(), ref.listen() NO reconstruye el widget.
  // Solo ejecuta el callback cuando el valor cambia.
  //
  // prev: el valor anterior (AsyncValue<bool>?).
  // next: el valor nuevo (AsyncValue<bool>).
  ref.listen<AsyncValue<bool>>(conectividadProvider, (prev, next) {
    // Obtener si hay conexion actualmente (o false si no se sabe).
    final tieneConexion = next.valueOrNull ?? false;

    // Detectar si se viene de un estado sin conexion.
    // prev?.valueOrNull ?? true: si prev es null (primera vez),
    // asumimos true para no disparar sincronizacion al inicio.
    // Este listener solo debe reaccionar a TRANSICIONES de red.
    final veniaDeSinConexion = !(prev?.valueOrNull ?? true);

    // Solo sincronizar cuando se PASA de "sin red" a "con red".
    // Esto evita sincronizar repetidamente si ya estabamos online.
    if (tieneConexion && veniaDeSinConexion) {
      _sincronizar(ref);
    }
  });

  // Intento inicial: al abrir la app, si ya hay conexion, sincronizar.
  // Esto asegura que cualquier parte pendiente se envie al iniciar.
  final tieneRedAhora = ref.read(conectividadProvider).valueOrNull ?? false;
  if (tieneRedAhora) {
    _sincronizar(ref);
  }

  // El provider retorna null porque no expone ningun dato util.
  // Su unico proposito es ejecutar side effects (sincronizacion).
  return null;
});

/// Envia al servidor todos los partes pendientes guardados sin conexion.
///
/// Procesa la cola offline en este orden:
///   1. Partes normales (creados por el trabajador).
///   2. Partes de jefe (creados por el supervisor).
///   3. Ediciones (updates) a partes existentes.
///
/// Usa una copia de la lista (List.from) para evitar errores si la
/// cola cambia mientras se procesa (ej. otro item agregado).
///
/// Si falla un parte, DETIENE todo el proceso (break). Ese parte
/// se reintentara en la proxima sincronizacion.
///
/// IMPORTANTE: Esta es la version BASICA. La version avanzada
/// (en sync_provider.dart) maneja errores 4xx descartando y 5xx
/// saltando elementos para no bloquear toda la cola.
Future<void> _sincronizar(Ref ref) async {
  // Obtener los servicios necesarios.
  final queue = ref.read(offlineQueueProvider);
  final api = ref.read(apiServiceProvider);
  final auth = ref.read(authServiceProvider);

  // Antes de sincronizar: asegurar que el token JWT es valido.
  // Si el token expiro, intenta renovarlo con el refresh_token.
  final tokenValido = await _asegurarToken(auth);
  if (!tokenValido) {
    // Token irrecuperable: forzar cierre de sesion.
    // Esto redirige al usuario a la pantalla de login.
    print(' Token expirado e irrecuperable. Forzando logout...');
    ref.read(authProvider.notifier).logout();
    return;
  }

  // --- 1. Partes Normales ---
  // Obtener todos los partes normales pendientes de la cola offline.
  final partes = await queue.getPartesOffline();
  if (partes.isNotEmpty) {
    // Iterar sobre una COPIA de la lista (List.from) para evitar
    // errores de concurrencia si la cola se modifica durante el loop.
    for (final parte in List.from(partes)) {
      try {
        // Enviar el parte al servidor (POST /api/partes/).
        await api.crearParte(parte);
        // Si se envio exitosamente, eliminar de la cola offline.
        await queue.borrarParteNormal(parte);
        // Actualizar el contador de pendientes en la UI.
        ref.invalidate(pendientesOfflineProvider);
      } catch (e) {
        // Si falla UN parte, detener todo el proceso (break).
        // Se reintentara en la proxima sincronizacion.
        break;
      }
    }
    // Despues de procesar, invalidar partesProvider para que recargue
    // los datos frescos desde el servidor (incluyendo los nuevos partes).
    ref.invalidate(partesProvider);
  }

  // --- 2. Partes de Jefe ---
  // Misma logica que los partes normales pero para partes de supervisor.
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
    // Recargar la vista de partes del jefe con datos actualizados.
    ref.invalidate(partesJefeProvider);
  }

  // --- 3. Updates (ediciones offline) ---
  // Procesar las modificaciones a partes existentes hechas sin conexion.
  final updates = await queue.getUpdatesOffline();
  if (updates.isNotEmpty) {
    for (final update in List.from(updates)) {
      try {
        // Extraer el ID del parte que se quiere modificar.
        final parteId = update['parteId'] as int;

        // Copiar los datos y quitar el campo parteId para enviar
        // solo los campos modificados al servidor.
        final data = Map<String, dynamic>.from(update)..remove('parteId');

        // Enviar la actualizacion al servidor (PUT /api/partes/:id/).
        await api.updateParte(parteId, data);
        await queue.borrarUpdate(update);
        ref.invalidate(pendientesOfflineProvider);
      } catch (e) {
        break;
      }
    }
    // Recargar la lista de partes con los datos actualizados.
    ref.invalidate(partesProvider);
  }
}

/// Revisa si el token de autenticacion sigue siendo valido.
///
/// Pasos:
///   1. Obtener el token JWT guardado en el telefono.
///   2. Si no hay token, retornar false (sesion invalida).
///   3. Si el token esta expirado, intentar renovarlo con refresh_token.
///   4. Si se pudo renovar, retornar true.
///   5. Si no se pudo renovar, retornar false (sesion expirada).
///
/// Retorna:
///   - true: token valido o renovado exitosamente.
///   - false: token no existe o no se pudo renovar.
Future<bool> _asegurarToken(AuthService auth) async {
  final token = await auth.getToken();
  if (token == null) return false;

  // Verificar si el token JWT esta vencido.
  if (auth.tokenExpirado(token)) {
    print(' Token expirado. Intentando refrescar...');
    // Intentar obtener un nuevo token usando el refresh_token.
    final nuevo = await auth.refrescarToken();
    return nuevo != null;
  }

  // Token aun valido, no necesita renovacion.
  return true;
}

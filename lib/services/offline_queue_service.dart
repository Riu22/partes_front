// =============================================================================
// offline_queue_service.dart  --  Cola de sincronizacion offline
// =============================================================================
// PROPOSITO:
//   Cuando la aplicacion no tiene conexion a internet, los partes de trabajo
//   no pueden enviarse al servidor. Este servicio actua como un "buzon de
//   correos temporal": guarda los datos localmente y los reenvia cuando la
//   conexion se restablece.
//
// ANALOGIA:
//   - OfflineQueueService es como un buzon de correos en una oficina cerrada.
//     Cuando el cartero (conexion) no puede pasar, dejas las cartas (partes)
//     en el buzon. Cuando el cartero vuelve (conexion restaurada), las recoge
//     y las entrega al destino (servidor).
//   - Las tres colas separadas son como tres bandejas distintas: una para
//     cartas normales, otra para cartas de jefes y otra para correcciones
//     de cartas ya enviadas.
//
// CONEXION CON EL RESTO DE LA APP:
//   - Un monitor de conectividad (ConnectivityService) detecta cuando la red
//     se recupera y dispara la sincronizacion llamando a los metodos de envio.
//   - Las pantallas de creacion de partes, cuando detectan que no hay internet,
//     llaman a guardarParteOffline / guardarParteJefeOffline en lugar de la API.
//   - Al iniciar la app, se verifica si hay elementos pendientes en la cola
//     y se intenta sincronizar (patron "sync on app start").
//
// PATRON DE COLA OFFLINE (explicacion):
//   Es un patron de diseno comun en apps moviles que necesitan funcionar sin
//   conexion. Los pasos son:
//   1. DETECTAR: el servicio de conectividad nota que no hay red.
//   2. ALMACENAR: los datos se guardan en almacenamiento local
//      (SharedPreferences en este caso, aunque SQLite seria mas escalable).
//   3. ENVOLVER: cada elemento se envuelve con un ID unico (UUID) y un
//      timestamp para poder identificarlo y ordenarlo despues.
//   4. REINTENTAR: cuando la red vuelve, se recorren los elementos en orden
//      cronologico y se envian al servidor uno por uno.
//   5. LIMPIAR: una vez enviado, cada elemento se elimina de la cola.
//   6. MANEJO DE ERRORES: si un elemento falla al enviarse, se deja en la cola
//      para un futuro reintento (no se bloquea el resto).
// =============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Cola de sincronizacion offline.
/// Cuando no hay conexion a internet, los partes se guardan aqui
/// y se envian automaticamente cuando se recupera la red.
///
/// Hay 3 colas separadas:
/// - partes normales (operario)
/// - partes de jefe de obra
/// - updates (ediciones de partes existentes)
///
/// Cada cola usa SharedPreferences como almacenamiento persistente.
/// Los datos se guardan como listas de strings JSON.
/// Cada elemento incluye metadatos: queue_id (UUID) y timestamp.
///
/// LIMITACIONES DEL DISENO:
///   - Usa SharedPreferences, que no es ideal para grandes volumenes de datos.
///     Para una app mas robusta, se recomienda SQLite (sqflite) o Hive.
///   - No hay limite de tamano de cola. Si el usuario esta offline mucho
///     tiempo, la cola puede crecer indefinidamente.
///   - No hay ordenacion explicita al recuperar. Se confia en el orden
///     de insercion de SharedPreferences (que suele ser FIFO).
class OfflineQueueService {
  // Claves para SharedPreferences: cada una representa una cola diferente
  static const _keyPartes = 'offline_partes';      // Cola de partes de operario
  static const _keyPartesJefe = 'offline_partes_jefe'; // Cola de partes de jefe
  static const _keyUpdates = 'offline_updates';    // Cola de ediciones pendientes

  /// Generador de UUID (identificadores unicos universales).
  /// Se usa para asignar un ID unico a cada elemento de la cola.
  final _uuid = const Uuid();

  /// Envuelve los datos con metadatos (ID unico y timestamp)
  /// para poder identificar cada elemento en la cola.
  ///
  /// Por que es necesario envolver los datos?
  ///   - Para poder borrar elementos especificos de la cola sin tener que
  ///     comparar todo el contenido (que podria ser identico entre elementos).
  ///   - Para saber el orden de creacion (timestamp) y enviar en orden FIFO.
  ///   - Para llevar trazabilidad (cada queue_id es unico y rastreable).
  ///
  /// [data] es el mapa original que se quiere guardar (ej: el parte de trabajo).
  /// Devuelve un nuevo mapa con: queue_id, timestamp y data.
  Map<String, dynamic> _envolver(Map<String, dynamic> data) {
    return {
      'queue_id': _uuid.v4(),   // UUID v4 aleatorio, ej: "550e8400-e29b-..."
      'timestamp': DateTime.now().millisecondsSinceEpoch, // Unix time en ms
      'data': data,              // Los datos originales del usuario
    };
  }

  // -------------------------------------------------------------------
  // METODOS PARA GUARDAR EN COLA
  // -------------------------------------------------------------------

  /// Guarda un parte de trabajo (operario) en la cola offline.
  /// Los datos se serializan a JSON y se anaden a la lista en SharedPreferences.
  Future<void> guardarParteOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Recarga para garantizar datos frescos
    final lista = _getLista(prefs, _keyPartes);
    lista.add(jsonEncode(_envolver(data)));
    await prefs.setStringList(_keyPartes, lista);
  }

  /// Guarda un parte de trabajo (jefe de obra) en la cola offline.
  /// Misma logica que guardarParteOffline pero en la cola de jefes.
  Future<void> guardarParteJefeOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = _getLista(prefs, _keyPartesJefe);
    lista.add(jsonEncode(_envolver(data)));
    await prefs.setStringList(_keyPartesJefe, lista);
  }

  /// Guarda una edicion de parte existente en la cola offline.
  /// A diferencia de los partes nuevos, una edicion necesita el ID del parte
  /// original (parteId) ademas de los datos modificados.
  ///
  /// [parteId] es el ID del parte a editar en el servidor.
  /// [data] son los campos modificados (solo los que cambiaron).
  Future<void> guardarUpdateOffline(int parteId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = _getLista(prefs, _keyUpdates);
    // Anade parteId a los datos antes de envolverlos
    lista.add(jsonEncode(_envolver({'parteId': parteId, ...data})));
    await prefs.setStringList(_keyUpdates, lista);
  }

  // -------------------------------------------------------------------
  // METODOS PARA LEER LA COLA
  // Devuelven los elementos completos con metadatos (queue_id, timestamp, data).
  // -------------------------------------------------------------------

  /// Devuelve todos los partes de operario pendientes de sincronizar.
  Future<List<Map<String, dynamic>>> getPartesOffline() async => _getWrappedItems(_keyPartes);

  /// Devuelve todos los partes de jefe pendientes de sincronizar.
  Future<List<Map<String, dynamic>>> getPartesJefeOffline() async => _getWrappedItems(_keyPartesJefe);

  /// Devuelve todas las ediciones pendientes de sincronizar.
  Future<List<Map<String, dynamic>>> getUpdatesOffline() async => _getWrappedItems(_keyUpdates);

  // -------------------------------------------------------------------
  // METODOS PARA BORRAR ELEMENTOS DE LA COLA POR SU ID UNICO
  // -------------------------------------------------------------------

  /// Borra un elemento de la cola identificado por su queue_id.
  ///
  /// [queueId] es el UUID unico del elemento a borrar.
  /// [key] es la clave de SharedPreferences (que cola).
  ///
  /// COMO FUNCIONA:
  ///   1. Lee la lista completa de SharedPreferences.
  ///   2. Convierte cada string JSON a mapa.
  ///   3. Filtra (elimina) el elemento cuyo queue_id coincide.
  ///   4. Vuelve a guardar la lista sin ese elemento.
  Future<void> _borrarPorQueueId(String queueId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = _getLista(prefs, key);

    // Recorre la lista y elimina el elemento con el queue_id especificado
    lista.removeWhere((itemStr) {
      try {
        final item = jsonDecode(itemStr) as Map<String, dynamic>;
        return item['queue_id'] == queueId;
      } catch (_) {
        // Si el JSON esta corrupto, lo elimina tambien
        return false;
      }
    });

    // Guarda la lista actualizada (sin el elemento borrado)
    await prefs.setStringList(key, lista);
  }

  /// Borra un parte de operario de la cola por su queue_id.
  /// [wrappedData] es el mapa completo devuelto por getPartesOffline()
  Future<void> borrarParteNormal(Map<String, dynamic> wrappedData) async {
    await _borrarPorQueueId(wrappedData['queue_id'] as String, _keyPartes);
  }

  /// Borra un parte de jefe de la cola por su queue_id.
  Future<void> borrarParteJefe(Map<String, dynamic> wrappedData) async {
    await _borrarPorQueueId(wrappedData['queue_id'] as String, _keyPartesJefe);
  }

  /// Borra una edicion de la cola por su queue_id.
  Future<void> borrarUpdate(Map<String, dynamic> wrappedData) async {
    await _borrarPorQueueId(wrappedData['queue_id'] as String, _keyUpdates);
  }

  // -------------------------------------------------------------------
  // LIMPIAR TODA LA COLA
  // -------------------------------------------------------------------

  /// Elimina todos los elementos de todas las colas.
  /// Se usa despues de una sincronizacion exitosa completa,
  /// o cuando el usuario cierra sesion (para no dejar datos de otro usuario).
  Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPartes);      // Limpia cola de partes operario
    await prefs.remove(_keyPartesJefe);  // Limpia cola de partes jefe
    await prefs.remove(_keyUpdates);     // Limpia cola de ediciones
  }

  // -------------------------------------------------------------------
  // UTILIDADES
  // -------------------------------------------------------------------

  /// Devuelve el numero total de elementos pendientes en todas las colas.
  /// Suma la longitud de las tres listas. Util para mostrar un badge o
  /// indicador en la interfaz de "X pendientes de sincronizar".
  Future<int> totalPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return _getLista(prefs, _keyPartes).length +
           _getLista(prefs, _keyPartesJefe).length +
           _getLista(prefs, _keyUpdates).length;
  }

  /// Lee una lista de strings de SharedPreferences para una clave dada.
  /// Si la clave no existe, devuelve una lista vacia (nunca null).
  List<String> _getLista(SharedPreferences prefs, String key) {
    return prefs.getStringList(key) ?? [];
  }

  /// Lee los elementos completos (con metadatos) de una cola.
  /// Cada string JSON se deserializa a Map<String, dynamic>.
  /// Los mapas resultantes contienen: queue_id, timestamp y data.
  Future<List<Map<String, dynamic>>> _getWrappedItems(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = _getLista(prefs, key);
    return lista.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }
}

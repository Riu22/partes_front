import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Cola de sincronización offline.
/// Cuando no hay conexión a internet, los partes se guardan aquí
/// y se envían automáticamente cuando se recupera la red.
///
/// Hay 3 colas separadas:
/// - partes normales (operario)
/// - partes de jefe de obra
/// - updates (ediciones de partes existentes)
class OfflineQueueService {
  static const _keyPartes = 'offline_partes';
  static const _keyPartesJefe = 'offline_partes_jefe';
  static const _keyUpdates = 'offline_updates';

  final _uuid = const Uuid();

  /// Envuelve los datos con metadatos (ID único y timestamp)
  /// para poder identificar cada elemento en la cola.
  Map<String, dynamic> _envolver(Map<String, dynamic> data) {
    return {
      'queue_id': _uuid.v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
  }

  // ── Guardar en cola ─────────────────────────────────

  Future<void> guardarParteOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = _getLista(prefs, _keyPartes);
    lista.add(jsonEncode(_envolver(data)));
    await prefs.setStringList(_keyPartes, lista);
  }

  Future<void> guardarParteJefeOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = _getLista(prefs, _keyPartesJefe);
    lista.add(jsonEncode(_envolver(data)));
    await prefs.setStringList(_keyPartesJefe, lista);
  }

  Future<void> guardarUpdateOffline(int parteId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = _getLista(prefs, _keyUpdates);
    lista.add(jsonEncode(_envolver({'parteId': parteId, ...data})));
    await prefs.setStringList(_keyUpdates, lista);
  }

  // ── Leer cola (devuelve elementos completos con metadatos) ──

  Future<List<Map<String, dynamic>>> getPartesOffline() async => _getWrappedItems(_keyPartes);
  Future<List<Map<String, dynamic>>> getPartesJefeOffline() async => _getWrappedItems(_keyPartesJefe);
  Future<List<Map<String, dynamic>>> getUpdatesOffline() async => _getWrappedItems(_keyUpdates);

  // ── Borrar elementos de la cola por su ID único ──

  Future<void> _borrarPorQueueId(String queueId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = _getLista(prefs, key);

    lista.removeWhere((itemStr) {
      try {
        final item = jsonDecode(itemStr) as Map<String, dynamic>;
        return item['queue_id'] == queueId;
      } catch (_) {
        return false;
      }
    });

    await prefs.setStringList(key, lista);
  }

  Future<void> borrarParteNormal(Map<String, dynamic> wrappedData) async {
    await _borrarPorQueueId(wrappedData['queue_id'] as String, _keyPartes);
  }

  Future<void> borrarParteJefe(Map<String, dynamic> wrappedData) async {
    await _borrarPorQueueId(wrappedData['queue_id'] as String, _keyPartesJefe);
  }

  Future<void> borrarUpdate(Map<String, dynamic> wrappedData) async {
    await _borrarPorQueueId(wrappedData['queue_id'] as String, _keyUpdates);
  }

  // ── Limpiar toda la cola ──

  Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPartes);
    await prefs.remove(_keyPartesJefe);
    await prefs.remove(_keyUpdates);
  }

  // ── Utilidades ──

  /// Devuelve el número total de elementos pendientes en todas las colas
  Future<int> totalPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return _getLista(prefs, _keyPartes).length +
           _getLista(prefs, _keyPartesJefe).length +
           _getLista(prefs, _keyUpdates).length;
  }

  List<String> _getLista(SharedPreferences prefs, String key) {
    return prefs.getStringList(key) ?? [];
  }

  Future<List<Map<String, dynamic>>> _getWrappedItems(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final lista = _getLista(prefs, key);
    return lista.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }
}

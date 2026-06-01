import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class OfflineQueueService {
  static const _keyPartes = 'offline_partes';
  static const _keyPartesJefe = 'offline_partes_jefe';
  static const _keyUpdates = 'offline_updates';

  final _uuid = const Uuid();

  /// Envuelve los datos de negocio con metadatos de control para la cola offline.
  Map<String, dynamic> _envolver(Map<String, dynamic> data) {
    return {
      'queue_id': _uuid.v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
  }

  // ── GUARDAR ──────────────────────────────
  Future<void> guardarParteOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Evita condiciones de carrera (Race Conditions)
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

  // ── LEER COLA (Devuelve elementos envueltos) ──
  Future<List<Map<String, dynamic>>> getPartesOffline() async => _getWrappedItems(_keyPartes);
  Future<List<Map<String, dynamic>>> getPartesJefeOffline() async => _getWrappedItems(_keyPartesJefe);
  Future<List<Map<String, dynamic>>> getUpdatesOffline() async => _getWrappedItems(_keyUpdates);

  // ── BORRADO ATÓMICO POR ID UNICO ──
  Future<void> _borrarPorQueueId(String queueId, String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Sincroniza con el disco inmediatamente antes de modificar
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

  // ── LIMPIAR TODO ───────────────────────────
  Future<void> limpiarTodo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPartes);
    await prefs.remove(_keyPartesJefe);
    await prefs.remove(_keyUpdates);
  }

  // ── UTILIDADES ────────────────────────────
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
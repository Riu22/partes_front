import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineQueueService {
  static const _keyPartes = 'offline_partes';
  static const _keyPartesJefe = 'offline_partes_jefe';

  // ── GUARDAR ──────────────────────────────
  Future<void> guardarParteOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _getLista(prefs, _keyPartes);
    lista.add(jsonEncode(data));
    await prefs.setStringList(_keyPartes, lista);
  }

  Future<void> guardarParteJefeOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _getLista(prefs, _keyPartesJefe);
    lista.add(jsonEncode(data));
    await prefs.setStringList(_keyPartesJefe, lista);
  }

  // ── LEER (Decodificando el JSON) ──────────
  Future<List<Map<String, dynamic>>> getPartesOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _getLista(prefs, _keyPartes);
    return lista.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getPartesJefeOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _getLista(prefs, _keyPartesJefe);
    return lista.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  // ── BORRADO INDIVIDUAL (Evita duplicados) ──
  // Estos métodos buscan el parte exacto que acabamos de enviar y lo quitan

  Future<void> borrarParteNormal(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _getLista(prefs, _keyPartes);
    final dataString = jsonEncode(data);

    lista.remove(dataString); // Quita solo esta entrada
    await prefs.setStringList(_keyPartes, lista);
  }

  Future<void> borrarParteJefe(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = _getLista(prefs, _keyPartesJefe);
    final dataString = jsonEncode(data);

    lista.remove(dataString);
    await prefs.setStringList(_keyPartesJefe, lista);
  }

  // ── LIMPIAR TODO (Opcional) ───────────────
  Future<void> limpiarPartesOffline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPartes);
  }

  Future<void> limpiarPartesJefeOffline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPartesJefe);
  }

  // ── UTILIDADES ────────────────────────────
  Future<int> totalPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final p = _getLista(prefs, _keyPartes).length;
    final j = _getLista(prefs, _keyPartesJefe).length;
    return p + j;
  }

  List<String> _getLista(SharedPreferences prefs, String key) {
    return prefs.getStringList(key) ?? [];
  }
}

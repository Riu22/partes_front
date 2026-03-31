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

  // ── LEER ─────────────────────────────────
  Future<List<Map<String, dynamic>>> getPartesOffline() async {
    final prefs = await SharedPreferences.getInstance();
    return _getLista(
      prefs,
      _keyPartes,
    ).map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getPartesJefeOffline() async {
    final prefs = await SharedPreferences.getInstance();
    return _getLista(
      prefs,
      _keyPartesJefe,
    ).map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  // ── LIMPIAR ───────────────────────────────
  Future<void> limpiarPartesOffline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPartes);
  }

  Future<void> limpiarPartesJefeOffline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPartesJefe);
  }

  Future<int> totalPendientes() async {
    final partes = await getPartesOffline();
    final jefe = await getPartesJefeOffline();
    return partes.length + jefe.length;
  }

  List<String> _getLista(SharedPreferences prefs, String key) {
    return prefs.getStringList(key) ?? [];
  }
}

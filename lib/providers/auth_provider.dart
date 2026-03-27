import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/perfil.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final apiServiceProvider = Provider((ref) => ApiService());

class AuthNotifier extends AsyncNotifier<Perfil?> {
  @override
  Future<Perfil?> build() async {
    _escucharEventosAuth();
    final token = await ref.read(authServiceProvider).getToken();
    if (token == null) return null;
    return await _cargarPerfil();
  }

  Future<Perfil?> _cargarPerfil() async {
    try {
      final data = await ref.read(apiServiceProvider).getMyProfile();
      return Perfil.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  void _escucharEventosAuth() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        print("Evento de recuperación detectado");
      }
    });
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncLoading();
    final token = await ref.read(authServiceProvider).login(email, password);
    if (token == null) {
      state = const AsyncData(null);
      return false;
    }
    final perfil = await _cargarPerfil();
    state = AsyncData(perfil);
    return perfil != null;
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData(null);
  }

  // Cambiamos el nombre a 'changePassword' para que coincida con tu pantalla
  Future<bool> changePassword(String newPassword) async {
    try {
      // Usamos el cliente global de Supabase directamente
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      print("Error en changePassword: $e");
      return false;
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, Perfil?>(
  AuthNotifier.new,
);

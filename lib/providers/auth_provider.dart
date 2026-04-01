import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/perfil.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';

final authServiceProvider = Provider((ref) => AuthService());
final apiServiceProvider = Provider((ref) => ApiService());

class AuthNotifier extends AsyncNotifier<Perfil?> {
  @override
  Future<Perfil?> build() async {
    final token = await ref.read(authServiceProvider).getToken();
    if (token == null) return null;

    final hayRed = await _checkRed();

    if (!hayRed) {
      final perfilLocal = await ref.read(authServiceProvider).getPerfilLocal();
      if (perfilLocal != null) return Perfil.fromJson(perfilLocal);
      return null;
    }

    return await _cargarPerfilServidor();
  }

  Future<Perfil?> _cargarPerfilServidor() async {
    try {
      final data = await ref.read(apiServiceProvider).getMyProfile();
      await ref.read(authServiceProvider).guardarPerfilLocal(data);
      return Perfil.fromJson(data);
    } catch (_) {
      // Si falla el servidor usar perfil local
      final perfilLocal = await ref.read(authServiceProvider).getPerfilLocal();
      if (perfilLocal != null) return Perfil.fromJson(perfilLocal);
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AsyncLoading();

    try {
      final hayRed = await _checkRed();

      if (!hayRed) {
        // Lógica de offline (mantenla igual o mejórala con un log)
        debugPrint('⚠️ Intento de login sin red detectado');
        // ... (tu lógica de perfil local)
        return false;
      }

      // Llamada al servicio de Supabase
      final token = await ref.read(authServiceProvider).login(email, password);

      if (token == null) {
        debugPrint(
          '❌ AuthService devolvió TOKEN NULL (Probablemente credenciales mal)',
        );
        state = const AsyncData(null);
        return false;
      }

      // Si hay token, cargamos el perfil
      final perfil = await _cargarPerfilServidor();
      state = AsyncData(perfil);
      return perfil != null;
    } catch (e, stack) {
      // ESTO ES CLAVE: Capturamos cualquier error que lance Supabase o el servicio
      debugPrint('🚨 EXCEPCIÓN EN AUTH_NOTIFIER: $e');
      debugPrint('📄 STACKTRACE: $stack');

      state = AsyncData(null); // Limpiamos el estado de carga
      return false;
    }
  }

  Future<bool> changePassword(String newPassword) async {
    try {
      await ref.read(authServiceProvider).cambiarPassword(newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData(null);
  }

  Future<bool> _checkRed() async {
    final resultado = await Connectivity().checkConnectivity();
    return resultado.any((r) => r != ConnectivityResult.none);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, Perfil?>(
  AuthNotifier.new,
);

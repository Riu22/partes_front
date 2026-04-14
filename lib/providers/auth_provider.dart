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
    } catch (e) {
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
        // --- LÓGICA OFFLINE ---
        debugPrint('⚠️ Intento de login sin red. Buscando perfil local...');
        final perfilLocal = await ref
            .read(authServiceProvider)
            .getPerfilLocal();

        if (perfilLocal != null) {
          state = AsyncData(Perfil.fromJson(perfilLocal));
          return true; // Permitimos entrar con lo que hay en caché
        }

        state = const AsyncData(null);
        return false;
      }

      // --- LÓGICA ONLINE (Aquí va el código que preguntaste) ---

      // 1. Intentamos el login en Supabase
      final token = await ref.read(authServiceProvider).login(email, password);

      if (token != null) {
        // 2. ¡CLAVE!: Borramos el perfil local antiguo para que no haya rastro del rol anterior
        await ref
            .read(authServiceProvider)
            .logout(); // Borra JWT y Perfil viejo de la caché

        // 3. Volvemos a guardar el token recién obtenido (porque el logout lo borró)
        await ref.read(authServiceProvider).guardarToken(token);

        // 4. Forzamos la descarga del perfil fresco desde el servidor (/user/me)
        final perfil = await _cargarPerfilServidor();

        state = AsyncData(perfil);
        return perfil != null;
      }

      state = const AsyncData(null);
      return false;
    } catch (e) {
      debugPrint('🚨 Error en login: $e');
      state = const AsyncData(null);
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

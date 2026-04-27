import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/perfil.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';

final authServiceProvider = Provider((ref) => AuthService());
final apiServiceProvider = Provider((ref) {
  final authService = ref.read(authServiceProvider);
  return ApiService(authService);
});

class AuthNotifier extends AsyncNotifier<Perfil?> {
  @override
  Future<Perfil?> build() async {
    final token = await ref.read(authServiceProvider).getToken();
    if (token == null) return null;

    final hayRed = await _checkRed();

    if (!hayRed) {
      // Sin red: entra con perfil local sin tocar el token
      final perfilLocal = await ref.read(authServiceProvider).getPerfilLocal();
      if (perfilLocal != null) return Perfil.fromJson(perfilLocal);
      return null;
    }

    // Con red: intenta cargar perfil. El interceptor 401 del ApiService
    // refresca el token automáticamente si hace falta.
    return await _cargarPerfilServidor();
  }

  Future<Perfil?> _cargarPerfilServidor() async {
    try {
      final data = await ref.read(apiServiceProvider).getMyProfile();
      await ref.read(authServiceProvider).guardarPerfilLocal(data);
      return Perfil.fromJson(data);
    } catch (e, stackTrace) {
      debugPrint('❌ Error cargando perfil: $e');
      debugPrint('📍 STACK TRACE: $stackTrace');
      // Si el refresh también falló, AuthService ya hizo logout()
      // y getToken() devolverá null la próxima vez → pantalla de login
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
        debugPrint('⚠️ Intento de login sin red. Buscando perfil local...');
        final perfilLocal = await ref
            .read(authServiceProvider)
            .getPerfilLocal();

        if (perfilLocal != null) {
          state = AsyncData(Perfil.fromJson(perfilLocal));
          return true;
        }

        state = const AsyncData(null);
        return false;
      }

      final token = await ref.read(authServiceProvider).login(email, password);

      if (token != null) {
        // Borramos perfil viejo (por si cambió el rol)
        await ref.read(authServiceProvider).logout();
        // Volvemos a guardar el token recién obtenido
        await ref.read(authServiceProvider).guardarToken(token);

        final perfil = await _cargarPerfilServidor();
        state = AsyncData(perfil);
        return perfil != null;
      }

      state = const AsyncData(null);
      return false;
    } catch (e, stackTrace) {
      debugPrint('🚨 Error en login: $e');
      debugPrint('📍 STACK TRACE: $stackTrace');
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

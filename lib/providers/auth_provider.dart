/// Proveedor de autenticación.
///
/// Maneja todo lo relacionado con la sesión del usuario:
/// iniciar sesión, cerrar sesión, cargar el perfil, cambiar la contraseña,
/// y recuperar la contraseña olvidada.
/// Cuando no hay internet, usa los datos guardados en el teléfono
/// para que la app siga funcionando sin conexión.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/perfil.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart';

/// Provee el servicio de autenticación.
///
/// Se encarga de las llamadas al servidor para iniciar sesión,
/// cerrar sesión, guardar el token, etc.
final authServiceProvider = Provider((ref) => AuthService());

/// Provee el servicio de API principal.
///
/// Necesita el servicio de autenticación para incluir el token
/// en las peticiones al servidor.
final apiServiceProvider = Provider((ref) {
  final authService = ref.read(authServiceProvider);
  return ApiService(authService);
});

/// Controla el estado de la sesión del usuario.
///
/// Este notifier mantiene el perfil del usuario que inició sesión,
/// y provee métodos para iniciar sesión, cerrarla, y manejar
/// la autenticación incluso cuando no hay conexión a internet.
class AuthNotifier extends AsyncNotifier<Perfil?> {
  @override
  /// Construye el estado inicial al abrir la app.
  ///
  /// Revisa si hay un token guardado (sesión previa). Si existe,
  /// intenta cargar el perfil del usuario. Si no hay internet,
  /// carga el perfil desde la copia guardada en el teléfono.
  /// Retorna el perfil del usuario, o null si no hay sesión activa.
  Future<Perfil?> build() async {
    // Al iniciar la app: si hay token guardado, intenta cargar el perfil
    final token = await ref.read(authServiceProvider).getToken();
    if (token == null) return null;

    final hayRed = await _checkRed();

    // Sin conexión: carga el perfil desde almacenamiento local
    if (!hayRed) {
      final perfilLocal = await ref.read(authServiceProvider).getPerfilLocal();
      if (perfilLocal != null) return Perfil.fromJson(perfilLocal);
      return null;
    }

    return await _cargarPerfilServidor();
  }

  /// Carga el perfil del usuario desde el servidor.
  ///
  /// Hace una petición a la API para obtener los datos del perfil.
  /// Si la petición falla (ej. no hay internet), usa la copia
  /// guardada localmente para no dejar al usuario sin datos.
  /// Retorna el perfil, o null si no se pudo obtener.
  Future<Perfil?> _cargarPerfilServidor() async {
    try {
      final data = await ref.read(apiServiceProvider).getMyProfile();
      // Guarda en local para uso offline futuro
      await ref.read(authServiceProvider).guardarPerfilLocal(data);
      return Perfil.fromJson(data);
    } catch (e, stackTrace) {
      debugPrint('❌ Error cargando perfil: $e');
      debugPrint('📍 STACK TRACE: $stackTrace');
      // Fallback al perfil local si falla el servidor
      final perfilLocal = await ref.read(authServiceProvider).getPerfilLocal();
      if (perfilLocal != null) return Perfil.fromJson(perfilLocal);
      return null;
    }
  }

  /// Inicia sesión con correo electrónico y contraseña.
  ///
  /// - [email]: el correo del usuario.
  /// - [password]: la contraseña del usuario.
  /// Si no hay internet, solo permite entrar si ya hay un perfil
  /// guardado localmente. Si hay internet, llama al servidor.
  /// Retorna `true` si pudo iniciar sesión correctamente.
  Future<bool> login(String email, String password) async {
    state = const AsyncLoading();

    try {
      final hayRed = await _checkRed();

      // Modo offline: permite login con perfil previamente cacheado
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

      // login() ya guarda jwt + refresh_token internamente via _guardarSesion()
      final token = await ref.read(authServiceProvider).login(email, password);

      if (token != null) {
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

  /// Cambia la contraseña del usuario que tiene la sesión activa.
  ///
  /// [newPassword] es la nueva contraseña que se quiere establecer.
  /// Retorna `true` si el cambio fue exitoso.
  Future<bool> changePassword(String newPassword) async {
    try {
      await ref.read(authServiceProvider).cambiarPassword(newPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cierra la sesión del usuario.
  ///
  /// Elimina el token de autenticación y los datos guardados,
  /// volviendo al estado inicial sin usuario.
  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    state = const AsyncData(null);
  }

  /// Revisa si el teléfono tiene conexión a internet.
  ///
  /// Retorna `true` si hay Wi-Fi, datos móviles o cualquier
  /// tipo de conexión de red activa.
  Future<bool> _checkRed() async {
    final resultado = await Connectivity().checkConnectivity();
    return resultado.any((r) => r != ConnectivityResult.none);
  }

  /// Solicita un correo para recuperar la contraseña olvidada.
  ///
  /// [email] es el correo con el que se registró el usuario.
  /// Retorna `true` si el correo de recuperación se envió correctamente.
  Future<bool> resetPassword(String email) async {
  return await ref.read(authServiceProvider).solicitarRecuperacion(email);
}
/// Cambia la contraseña usando un token de recuperación.
///
/// Se usa cuando el usuario hace clic en el enlace de recuperación
/// que llegó a su correo. [token] es el código de recuperación
/// y [newPassword] es la nueva contraseña.
/// Retorna `true` si el cambio fue exitoso.
Future<bool> changePasswordConToken(String token, String newPassword) async {
  try {
    await ref.read(authServiceProvider).cambiarPasswordConToken(token, newPassword);
    return true;
  } catch (e) {
    debugPrint('❌ Error changePasswordConToken: $e');
    return false;
  }
}
}

/// Provee el estado de autenticación de la app.
///
/// Expone el perfil del usuario actual (o null si no hay sesión)
/// y permite iniciar/cerrar sesión desde cualquier parte de la app.
final authProvider = AsyncNotifierProvider<AuthNotifier, Perfil?>(
  AuthNotifier.new,
);

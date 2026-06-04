import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';
import '../helpers/url_helper.dart';

/// Servicio de autenticación: login, logout, refresh de token, cambio de contraseña.
/// Usa Supabase Auth como backend y guarda los tokens en almacenamiento seguro.
class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Caché del token JWT en memoria (evita leer de disco constantemente)
  String? _tokenCache;

  String get _anonKey => Env.supabaseAnonKey;

  /// Inicia sesión con email y contraseña contra Supabase Auth.
  /// Devuelve el access_token si OK, o null si falla.
  Future<String?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '${Env.supabaseUrl}/auth/v1/token?grant_type=password',
        data: {'email': email, 'password': password},
        options: Options(
          headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
        ),
      );
      await _guardarSesion(response.data);
      return response.data['access_token'];
    } on DioException catch (e) {
      _handleError(e);
      return null;
    } catch (e, stackTrace) {
      debugPrint('Error inesperado en login: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Guarda el access_token y refresh_token en el almacenamiento seguro.
  /// También los guarda en caché en memoria.
  Future<void> _guardarSesion(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String?;
    await _storage.write(key: 'jwt', value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }
    _tokenCache = accessToken;
  }

  /// Intenta renovar el token JWT usando el refresh_token guardado.
  /// Si el refresh también falla, hace logout automático.
  Future<String?> refrescarToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return null;
    try {
      final response = await _dio.post(
        '${Env.supabaseUrl}/auth/v1/token?grant_type=refresh_token',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
        ),
      );
      await _guardarSesion(response.data);
      return response.data['access_token'];
    } catch (e) {
      await logout();
      return null;
    }
  }

  /// Comprueba si un JWT ha expirado examinando su payload (campo 'exp').
  bool tokenExpirado(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return true;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final exp = decoded['exp'] as int?;
      if (exp == null) return true;
      final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expDate.subtract(const Duration(seconds: 30)));
    } catch (_) {
      return true;
    }
  }

  Future<void> guardarToken(String token) async {
    await _storage.write(key: 'jwt', value: token);
    _tokenCache = token;
  }

  Future<void> guardarRefreshToken(String token) async {
    await _storage.write(key: 'refresh_token', value: token);
  }

  /// Lee el token JWT guardado (primero de caché, luego de disco)
  Future<String?> getToken() async {
    _tokenCache = await _storage.read(key: 'jwt');
    return _tokenCache;
  }

  /// Guarda el perfil del usuario en almacenamiento local para uso offline
  Future<void> guardarPerfilLocal(Map<String, dynamic> perfil) async {
    await _storage.write(key: 'perfil', value: jsonEncode(perfil));
  }

  /// Recupera el perfil guardado localmente (para modo offline)
  Future<Map<String, dynamic>?> getPerfilLocal() async {
    final raw = await _storage.read(key: 'perfil');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Cambia el email del usuario autenticado
  Future<void> cambiarEmail(String nuevoEmail) async {
    final token = await getToken();
    await _dio.put(
      '${Env.supabaseUrl}/auth/v1/user',
      data: {'email': nuevoEmail},
      options: Options(
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  /// Cierra sesión: borra token, refresh token y perfil local
  Future<void> logout() async {
    _tokenCache = null;
    await _storage.deleteAll();
  }

  /// Cambia la contraseña del usuario autenticado
  Future<void> cambiarPassword(String nuevaPassword) async {
    final token = await getToken();
    await _dio.put(
      '${Env.supabaseUrl}/auth/v1/user',
      data: {'password': nuevaPassword},
      options: Options(
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  /// Cambia la contraseña usando un token de recuperación (no requiere sesión activa)
  Future<void> cambiarPasswordConToken(String token, String nuevaPassword) async {
    debugPrint('Token usado para cambio password: ${token.substring(0, 20)}...');
    await _dio.put(
      '${Env.supabaseUrl}/auth/v1/user',
      data: {'password': nuevaPassword},
      options: Options(
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  /// Solicita un email de recuperación de contraseña
  Future<bool> solicitarRecuperacion(String email) async {
    try {
      await _dio.post(
        '${Env.supabaseUrl}/auth/v1/recover',
        data: {'email': email},
        options: Options(
          headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
        ),
        queryParameters: {'redirect_to': '${Env.appUrl}/#/nueva-password'},
      );
      return true;
    } catch (e) {
      debugPrint('Error al solicitar recuperación: $e');
      return false;
    }
  }

  /// Extrae el token de recuperación desde la URL del enlace mágico.
  /// La URL tiene formato: app://#access_token=xxx&refresh_token=yyy&type=recovery
  Future<String?> verificarTokenRecuperacion(Uri uri) async {
    final fullUrl = getCurrentUrl(uri);
    debugPrint('URL raw de recuperación: $fullUrl');

    final separador = fullUrl.contains('%23') ? '%23' : '#';
    final lastIndex = fullUrl.lastIndexOf(separador);
    if (lastIndex == -1) return null;

    final paramString = Uri.decodeComponent(
      fullUrl.substring(lastIndex + separador.length)
    );
    final params = Uri.splitQueryString(paramString);
    debugPrint('Parámetros extraídos: $params');

    final type = params['type'];
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];

    if (accessToken == null || type != 'recovery') return null;

    await guardarToken(accessToken);
    if (refreshToken != null) await guardarRefreshToken(refreshToken);

    debugPrint('Token de recuperación válido: ${accessToken.substring(0, 20)}...');
    return accessToken;
  }

  /// Muestra errores de red en consola para depuración
  void _handleError(DioException e) {
    if (e.response != null) {
      debugPrint('Error HTTP ${e.response?.statusCode}: ${e.response?.data}');
    } else {
      debugPrint('Error de conexión: ${e.message}');
    }
  }
}

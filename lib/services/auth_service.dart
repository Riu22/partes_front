import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _tokenCache;

  String get _anonKey => Env.supabaseAnonKey;

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
      debugPrint('❌ ERROR INESPERADO: $e');
      debugPrint('📍 STACK TRACE: $stackTrace');
      return null;
    }
  }

  Future<void> _guardarSesion(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String?;
    await _storage.write(key: 'jwt', value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }
    _tokenCache = accessToken;
  }

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

  Future<String?> getToken() async {
    _tokenCache = await _storage.read(key: 'jwt');
    return _tokenCache;
  }

  Future<void> guardarPerfilLocal(Map<String, dynamic> perfil) async {
    await _storage.write(key: 'perfil', value: jsonEncode(perfil));
  }

  Future<Map<String, dynamic>?> getPerfilLocal() async {
    final raw = await _storage.read(key: 'perfil');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

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

  Future<void> logout() async {
    _tokenCache = null;
    await _storage.deleteAll();
  }

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

  Future<void> cambiarPasswordConToken(String token, String nuevaPassword) async {
    debugPrint('🔑 Token usado: ${token.substring(0, 20)}...');
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
      debugPrint('❌ Error solicitarRecuperacion: $e');
      return false;
    }
  }

  Future<String?> verificarTokenRecuperacion(Uri uri) async {
    final fragment = uri.fragment;
    debugPrint('📦 Fragment: $fragment');

    final hashIndex = fragment.indexOf('#');
    if (hashIndex == -1) return null;

    final paramString = fragment.substring(hashIndex + 1);
    final params = Uri.splitQueryString(paramString);
    debugPrint('📦 Params: $params');

    final type = params['type'];
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];

    if (accessToken == null || type != 'recovery') return null;

    await guardarToken(accessToken);
    if (refreshToken != null) await guardarRefreshToken(refreshToken);

    debugPrint('✅ Token recovery: ${accessToken.substring(0, 20)}...');
    return accessToken;
  }

  void _handleError(DioException e) {
    if (e.response != null) {
      debugPrint('❌ ERROR ${e.response?.statusCode}: ${e.response?.data}');
    } else {
      debugPrint('❌ ERROR DE CONEXIÓN: ${e.message}');
    }
  }
}
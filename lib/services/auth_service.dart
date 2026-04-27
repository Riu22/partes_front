import 'dart:convert';
import 'package:dio/dio.dart';
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
      print('❌ ERROR INESPERADO: $e');
      print('📍 STACK TRACE: $stackTrace');
      return null;
    }
  }

  Future<void> _guardarSesion(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String?;

    _tokenCache = accessToken;
    await _storage.write(key: 'jwt', value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }
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
      return DateTime.now().isAfter(
        expDate.subtract(const Duration(seconds: 30)),
      );
    } catch (_) {
      return true;
    }
  }

  Future<void> guardarToken(String token) async {
    _tokenCache = token;
    await _storage.write(key: 'jwt', value: token);
  }

  Future<String?> getToken() async {
    if (_tokenCache != null) return _tokenCache;
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
      return false;
    }
  }

  void _handleError(DioException e) {
    if (e.response != null) {
      print('❌ ERROR ${e.response?.statusCode}: ${e.response?.data}');
    } else {
      print('❌ ERROR DE CONEXIÓN: ${e.message}');
    }
  }
}

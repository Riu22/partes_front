import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ✅ Cache en memoria
  String? _tokenCache;

  // ✅ Obtiene la key desde Env (prioriza el .env)
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

      final token = response.data['access_token'];
      await guardarToken(token);
      return token;
    } on DioException catch (e) {
      _handleError(e);
      return null;
    } catch (e, stackTrace) {
      print('❌ ERROR INESPERADO: $e');
      print('📍 STACK TRACE: $stackTrace');
      return null;
    }
  }

  // --- MÉTODOS QUE FALTABAN ---

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

  // --- RESTO DE MÉTODOS ---

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

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _tokenCache;

  // ✅ Ahora pedimos la llave a Env (que mirará primero el .env)
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
      _tokenCache = token;
      await _storage.write(key: 'jwt', value: token);
      return token;
    } on DioException catch (e) {
      _handleError(e);
      return null;
    } catch (e) {
      print('❌ ERROR INESPERADO: $e');
      return null;
    }
  }

  // --- MÉTODOS DE APOYO ---

  Future<String?> getToken() async {
    if (_tokenCache != null) return _tokenCache;
    _tokenCache = await _storage.read(key: 'jwt');
    return _tokenCache;
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

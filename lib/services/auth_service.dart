import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ✅ Cache en memoria — evita ir a SecureStorage en cada petición
  String? _tokenCache;

  final String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

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
      _tokenCache = token; // ✅ Guardar en memoria primero
      await _storage.write(key: 'jwt', value: token);
      return token;
    } on DioException catch (e) {
      if (e.response != null) {
        print('❌ CÓDIGO SERVIDOR: ${e.response?.statusCode}');
        print('❌ MENSAJE SERVIDOR: ${e.response?.data}');
      } else {
        print('❌ ERROR SIN RESPUESTA: ${e.message}');
      }
      return null;
    } catch (e) {
      print('❌ ERROR INESPERADO: $e');
      return null;
    }
  }

  Future<String?> getToken() async {
    // ✅ Si ya está en memoria, devolver inmediatamente sin tocar SecureStorage
    if (_tokenCache != null) return _tokenCache;

    // Solo ir a SecureStorage si no hay cache (primer arranque de la app)
    _tokenCache = await _storage.read(key: 'jwt');
    return _tokenCache;
  }

  Future<void> guardarToken(String token) async {
    _tokenCache = token; // ✅ Actualizar cache también
    await _storage.write(key: 'jwt', value: token);
  }

  Future<void> guardarPerfilLocal(Map<String, dynamic> perfil) async {
    await _storage.write(key: 'perfil', value: jsonEncode(perfil));
  }

  Future<Map<String, dynamic>?> getPerfilLocal() async {
    final raw = await _storage.read(key: 'perfil');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    _tokenCache = null; // ✅ Limpiar cache al cerrar sesión
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
          headers: {
            'apikey': _anonKey,
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_anonKey',
          },
        ),
        queryParameters: {'redirect_to': '${Env.appUrl}/#/nueva-password'},
      );
      return true;
    } catch (e) {
      return false;
    }
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
}

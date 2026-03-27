import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  // Supabase local en Docker
  final String _supabaseUrl = 'http://localhost:8000';
  // La anon key de tu Supabase local — la encuentras en el dashboard o en docker-compose
  final String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';
  Future<String?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '$_supabaseUrl/auth/v1/token?grant_type=password',
        data: {'email': email, 'password': password},
        options: Options(
          headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
        ),
      );
      final token = response.data['access_token'];
      await _storage.write(key: 'jwt', value: token);
      return token;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt');
  }

  Future<void> cambiarPassword(String nuevaPassword) async {
    final token = await getToken();
    await _dio.put(
      '$_supabaseUrl/auth/v1/user',
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
        '$_supabaseUrl/auth/v1/recover',
        data: {'email': email},
        options: Options(
          headers: {
            'apikey': _anonKey,
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_anonKey',
          },
        ),
        // Añadimos el query parameter para la redirección
        queryParameters: {
          'redirect_to': 'http://localhost:3000/#/nueva-password',
        },
      );
      return true;
    } catch (e) {
      print("Error en recover: $e");
      return false;
    }
  }

  Future<void> cambiarEmail(String nuevoEmail) async {
    final token = await getToken();
    await _dio.put(
      '$_supabaseUrl/auth/v1/user',
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

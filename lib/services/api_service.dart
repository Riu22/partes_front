import 'package:dio/dio.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8081/api/v1'));
  final AuthService _authService = AuthService();

  Future<Options> _authHeaders() async {
    final token = await _authService.getToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _dio.get('/user/me', options: await _authHeaders());
    return response.data;
  }

  Future<List<dynamic>> getPartes() async {
    final response = await _dio.get(
      '/partes/get_partes',
      options: await _authHeaders(),
    );
    return response.data;
  }

  Future<void> crearParte(Map<String, dynamic> data) async {
    await _dio.post(
      '/partes/new_parte',
      data: data,
      options: await _authHeaders(),
    );
  }

  Future<List<dynamic>> getObras() async {
    final response = await _dio.get('/obra', options: await _authHeaders());
    return response.data;
  }
}

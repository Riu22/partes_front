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

  Future<void> validarParte(int parteId) async {
    await _dio.put('/partes/validar/$parteId', options: await _authHeaders());
  }

  // USUARIOS
  Future<List<dynamic>> getUsuarios() async {
    final response = await _dio.get('/user/all', options: await _authHeaders());
    return response.data;
  }

  Future<void> crearUsuario(Map<String, dynamic> data) async {
    await _dio.post(
      '/user/create_user',
      data: data,
      options: await _authHeaders(),
    );
  }

  Future<void> editarUsuario(String id, Map<String, dynamic> data) async {
    await _dio.put(
      '/user/update_user/$id',
      data: data,
      options: await _authHeaders(),
    );
  }

  Future<void> eliminarUsuario(String id) async {
    await _dio.delete('/user/delete_user/$id', options: await _authHeaders());
  }

  Future<void> asignarJefe(String subordinadoId, String jefeId) async {
    await _dio.put(
      '/asignaciones/asignar_encargado/$subordinadoId/$jefeId',
      options: await _authHeaders(),
    );
  }

  // OBRAS
  Future<void> crearObra(Map<String, dynamic> data) async {
    await _dio.post('/obra', data: data, options: await _authHeaders());
  }

  Future<void> editarObra(int id, Map<String, dynamic> data) async {
    await _dio.put(
      '/obra/update_obra/$id',
      data: data,
      options: await _authHeaders(),
    );
  }

  Future<void> eliminarObra(int id) async {
    await _dio.delete('/obra/delete/$id', options: await _authHeaders());
  }

  Future<List<dynamic>> getAsignacionesObra(int obraId) async {
    final response = await _dio.get(
      '/asignaciones/obra/$obraId',
      options: await _authHeaders(),
    );
    return response.data;
  }

  Future<void> asignarAObra(String perfilId, int obraId) async {
    await _dio.post(
      '/asignaciones/asignar_a_obra/$perfilId/$obraId',
      options: await _authHeaders(),
    );
  }

  Future<void> eliminarAsignacionObra(int asignacionId) async {
    await _dio.delete(
      '/asignaciones/eliminar/$asignacionId',
      options: await _authHeaders(),
    );
  }

  Future<List<dynamic>> getMisObras() async {
    final response = await _dio.get(
      '/asignaciones/mis_obras',
      options: await _authHeaders(),
    );
    return response.data;
  }
}

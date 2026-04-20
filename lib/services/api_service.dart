import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../config/env.dart';
import '../models/parte_trabajo.dart';
import 'dart:typed_data';
import '../helpers/download_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: Env.apiUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ),
  );
  final AuthService _authService;

  ApiService([AuthService? authService])
    : _authService = authService ?? AuthService();
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

  Future<ParteTrabajo> updateParte(
    int parteId,
    Map<String, dynamic> data,
  ) async {
    final response = await _dio.put(
      '/partes/update/$parteId',
      data: data,
      options: await _authHeaders(),
    );
    return ParteTrabajo.fromJson(response.data);
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

  Future<List<dynamic>> getSubordinadosDe(String jefeId) async {
    final response = await _dio.get(
      '/asignaciones/$jefeId/subordinados',
      options: await _authHeaders(),
    );
    return response.data;
  }

  Future<void> asignarJefe(
    String usuarioId,
    String jefeId,
    String rolJefe,
  ) async {
    String endpoint = (rolJefe == 'JEFE_DE_OBRA')
        ? 'asignar_encargado'
        : 'asignar_operario';

    await _dio.put(
      '/asignaciones/$endpoint/$usuarioId/$jefeId',
      options: await _authHeaders(),
    );
  }

  Future<void> quitarSubordinado(String usuarioId) async {
    await _dio.delete(
      '/asignaciones/quitar_subordinado/$usuarioId',
      options: await _authHeaders(),
    );
  }

  // OBRAS
  Future<void> crearObra(Map<String, dynamic> data) async {
    try {
      await _dio.post('/obra', data: data, options: await _authHeaders());
    } on DioException catch (e) {
      // Si hay respuesta del servidor (como el 409 CONFLICT)
      if (e.response != null) {
        // Importante: Si el body es un String simple, e.response?.data ya es el error.
        // Si el error persiste, usa e.response?.data.toString()
        throw e.response?.data.toString() ?? "Error en el servidor";
      }
    } catch (e) {
      throw "Error de conexión inesperado";
    }
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

  Future<void> crearParteJefe(Map<String, dynamic> data) async {
    await _dio.post(
      '/partes/new_parte_jefe',
      data: data,
      options: await _authHeaders(),
    );
  }

  Future<List<dynamic>> getPartesJefe() async {
    final response = await _dio.get(
      '/partes/get_partes_jefe',
      options: await _authHeaders(),
    );
    return response.data;
  }

  Future<List<dynamic>> buscarPartes({
    String? obra,
    String? operario,
    String? especialidad,
  }) async {
    final params = <String, String>{};
    if (obra != null && obra.isNotEmpty) params['obra'] = obra;
    if (operario != null && operario.isNotEmpty) params['operario'] = operario;
    if (especialidad != null) params['especialidad'] = especialidad;

    final response = await _dio.get(
      '/partes/buscar',
      queryParameters: params,
      options: await _authHeaders(),
    );
    return response.data;
  }

  Future<List<dynamic>> getQuincena(String desde, String hasta) async {
    final response = await _dio.get(
      '/quincena',
      queryParameters: {'desde': desde, 'hasta': hasta},
      options: await _authHeaders(),
    );
    return response.data;
  }

  Future<void> exportarQuincena(String desde, String hasta) async {
    final response = await _dio.get(
      '/quincena/exportar',
      queryParameters: {'desde': desde, 'hasta': hasta},
      options: Options(
        headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
        responseType: ResponseType.bytes,
      ),
    );

    if (response.data != null) {
      saveAndLaunchFile(
        Uint8List.fromList(response.data),
        'quincena_$desde\_$hasta.csv',
      );
    }
  }

  Future<List<dynamic>> getContabilidadDetalleJson(
    DateTime desde,
    DateTime hasta,
  ) async {
    String desdeStr =
        "${desde.year}-${desde.month.toString().padLeft(2, '0')}-${desde.day.toString().padLeft(2, '0')}";
    String hastaStr =
        "${hasta.year}-${hasta.month.toString().padLeft(2, '0')}-${hasta.day.toString().padLeft(2, '0')}";

    final response = await _dio.get(
      '/quincena/contabilidad-detalle-json',
      queryParameters: {'desde': desdeStr, 'hasta': hastaStr},
      options: await _authHeaders(),
    );
    return response.data;
  }

  /// Descarga el archivo CSV procesado
  Future<void> exportarContabilidadDetalleCsv(
    DateTime desde,
    DateTime hasta,
  ) async {
    String desdeStr =
        "${desde.year}-${desde.month.toString().padLeft(2, '0')}-${desde.day.toString().padLeft(2, '0')}";
    String hastaStr =
        "${hasta.year}-${hasta.month.toString().padLeft(2, '0')}-${hasta.day.toString().padLeft(2, '0')}";

    try {
      final response = await _dio.get(
        '/quincena/exportar-detalle-csv',
        queryParameters: {'desde': desdeStr, 'hasta': hastaStr},
        options: Options(
          headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
          responseType: ResponseType.bytes, // IMPORTANTE para archivos
        ),
      );

      if (response.data != null) {
        saveAndLaunchFile(
          Uint8List.fromList(response.data),
          'detalle_contabilidad_$desdeStr\_$hastaStr.csv',
        );
      }
    } catch (e) {
      throw "Error al exportar CSV detallado: $e";
    }
  }
}

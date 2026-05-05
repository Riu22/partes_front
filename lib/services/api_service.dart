import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../config/env.dart';
import '../models/parte_trabajo.dart';
import 'dart:typed_data';
import '../helpers/download_helper.dart';

class ApiService {
  late final Dio _dio;
  final AuthService _authService;
  bool _refrescando = false;

  ApiService([AuthService? authService])
    : _authService = authService ?? AuthService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final is401 = error.response?.statusCode == 401;
          final yaReintentado = error.requestOptions.extra['retried'] == true;

          if (is401 && !yaReintentado && !_refrescando) {
            _refrescando = true;
            final nuevoToken = await _authService.refrescarToken();
            _refrescando = false;

            if (nuevoToken != null) {
              final opts = error.requestOptions
                ..headers['Authorization'] = 'Bearer $nuevoToken'
                ..extra['retried'] = true;

              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  Future<Options> _authHeaders() async {
    final token = await _authService.getToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ─────────────────────────────────────────
  // Perfil
  // ─────────────────────────────────────────

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _dio.get('/user/me', options: await _authHeaders());
    return response.data;
  }

  // ─────────────────────────────────────────
  // Partes
  // ─────────────────────────────────────────

  Future<List<dynamic>> getPartes() async {
    final response = await _dio.get(
      '/partes/get_partes',
      options: await _authHeaders(),
    );
    return response.data;
  }

  Future<void> crearParte(Map<String, dynamic> data) async {
    try {
      await _dio.post(
        '/partes/new_parte',
        data: data,
        options: await _authHeaders(),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data?.toString() ?? 'Error del servidor';
      }
      rethrow;
    }
  }

  Future<void> crearParteJefe(Map<String, dynamic> data) async {
    try {
      await _dio.post(
        '/partes/new_parte_jefe',
        data: data,
        options: await _authHeaders(),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data?.toString() ?? 'Error del servidor';
      }
      rethrow;
    }
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

  // ─────────────────────────────────────────
  // Fechas con parte — para el DatePicker
  // ─────────────────────────────────────────

  Future<List<DateTime>> getMisFechasConParte() async {
    try {
      final response = await _dio.get(
        '/partes/mis-fechas-con-parte',
        options: await _authHeaders(),
      );
      return (response.data as List)
          .map((s) => DateTime.parse(s.toString()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DateTime>> getFechasConParte(String id) async {
    try {
      final response = await _dio.get(
        '/partes/fechas-con-parte/$id',
        options: await _authHeaders(),
      );
      return (response.data as List)
          .map((s) => DateTime.parse(s.toString()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────
  // Obras
  // ─────────────────────────────────────────

  Future<List<dynamic>> getObras() async {
    final response = await _dio.get('/obra', options: await _authHeaders());
    return response.data;
  }

  Future<List<dynamic>> getObrasActivas() async {
    final response = await _dio.get(
      '/obra/activas',
      options: await _authHeaders(),
    );
    return response.data;
  }

  Future<void> crearObra(Map<String, dynamic> data) async {
    try {
      await _dio.post('/obra', data: data, options: await _authHeaders());
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data.toString() ?? 'Error en el servidor';
      }
    } catch (e) {
      throw 'Error de conexión inesperado';
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

  // ─────────────────────────────────────────
  // Usuarios
  // ─────────────────────────────────────────

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

  // ─────────────────────────────────────────
  // Asignaciones
  // ─────────────────────────────────────────

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
    final endpoint = (rolJefe == 'JEFE_DE_OBRA')
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

  // ─────────────────────────────────────────
  // Partes jefe
  // ─────────────────────────────────────────

  Future<List<dynamic>> getPartesJefe() async {
    final response = await _dio.get(
      '/partes/get_partes_jefe',
      options: await _authHeaders(),
    );
    return response.data;
  }

  // ─────────────────────────────────────────
  // Quincena
  // ─────────────────────────────────────────

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
        'quincena_${desde}_$hasta.csv',
      );
    }
  }

  Future<List<dynamic>> getContabilidadDetalleJson(
    DateTime desde,
    DateTime hasta,
  ) async {
    final desdeStr = _fmtDate(desde);
    final hastaStr = _fmtDate(hasta);
    final response = await _dio.get(
      '/quincena/contabilidad-detalle-json',
      queryParameters: {'desde': desdeStr, 'hasta': hastaStr},
      options: await _authHeaders(),
    );
    return response.data;
  }

  Future<void> exportarContabilidadDetalleCsv(
    DateTime desde,
    DateTime hasta,
  ) async {
    final desdeStr = _fmtDate(desde);
    final hastaStr = _fmtDate(hasta);
    try {
      final response = await _dio.get(
        '/quincena/exportar-detalle-csv',
        queryParameters: {'desde': desdeStr, 'hasta': hastaStr},
        options: Options(
          headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
          responseType: ResponseType.bytes,
        ),
      );
      if (response.data != null) {
        saveAndLaunchFile(
          Uint8List.fromList(response.data),
          'detalle_contabilidad_${desdeStr}_$hastaStr.csv',
        );
      }
    } catch (e) {
      throw 'Error al exportar CSV detallado: $e';
    }
  }

  // ─────────────────────────────────────────
  // Fecha libre — gestión de días permitidos
  // ─────────────────────────────────────────

  Future<void> habilitarFechas(String id, List<DateTime> fechas) async {
    final body = fechas.map(_fmtDate).toList();
    await _dio.post(
      '/config/fecha-libre/habilitar/$id',
      data: body,
      options: Options(
        headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
        contentType: 'application/json', // 👈 esto
      ),
    );
  }

  Future<void> deshabilitarFecha(String id, DateTime fecha) async {
    await _dio.delete(
      '/config/fecha-libre/deshabilitar/$id/${_fmtDate(fecha)}',
      options: await _authHeaders(),
    );
  }

  Future<void> deshabilitarFechaLibre(String id) async {
    await _dio.delete(
      '/config/fecha-libre/deshabilitar/$id',
      options: await _authHeaders(),
    );
  }

  Future<Map<String, List<DateTime>>> getFechaLibreActivos() async {
    final response = await _dio.get(
      '/config/fecha-libre',
      options: await _authHeaders(),
    );
    final raw = response.data as Map<String, dynamic>;
    return raw.map(
      (userId, fechas) => MapEntry(
        userId,
        (fechas as List).map((s) => DateTime.parse(s.toString())).toList(),
      ),
    );
  }

  Future<List<DateTime>> getMisFechasLibres() async {
    try {
      final response = await _dio.get(
        '/config/fecha-libre/mis-fechas',
        options: await _authHeaders(),
      );
      return (response.data as List)
          .map((s) => DateTime.parse(s.toString()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

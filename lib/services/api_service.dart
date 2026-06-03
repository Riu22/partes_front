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
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
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
  // Usuarios
  // ─────────────────────────────────────────

  Future<List<dynamic>> getUsuarios() async {
    final response = await _dio.get('/user/all', options: await _authHeaders());
    return (response.data as List?) ?? [];
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
  // Obras
  // ─────────────────────────────────────────

  Future<List<dynamic>> getObras() async {
    final response = await _dio.get('/obra', options: await _authHeaders());
    return (response.data as List?) ?? [];
  }

  Future<List<dynamic>> getObrasActivas() async {
    final response = await _dio.get(
      '/obra/activas',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  Future<void> crearObra(Map<String, dynamic> data) async {
    try {
      await _dio.post('/obra', data: data, options: await _authHeaders());
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data.toString() ?? 'Error en el servidor';
      }
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
  // Asignaciones
  // ─────────────────────────────────────────

  Future<List<dynamic>> getSubordinadosDe(String jefeId) async {
    final response = await _dio.get(
      '/asignaciones/$jefeId/subordinados',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  Future<void> asignarJefe(
    String subordinadoId,
    String jefeId,
    String rolJefe,
  ) async {
    await _dio.put(
      '/asignaciones/asignar_subordinado/$subordinadoId/$jefeId',
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
    return (response.data as List?) ?? [];
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
    return (response.data as List?) ?? [];
  }

  Future<List<dynamic>> getObrasDePerfil(String perfilId) async {
    final response = await _dio.get(
      '/asignaciones/perfil/$perfilId',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  Future<void> asignarSubordinadosBatch(
      String jefeId, List<String> subordinadoIds) async {
    final token = await _authService.getToken();
    await _dio.put(
      '/asignaciones/asignar_subordinados_batch/$jefeId',
      data: subordinadoIds,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Future<void> asignarPerfilAObra(String perfilId, int obraId) async {
    await _dio.post(
      '/asignaciones/asignar_a_obra/$perfilId/$obraId',
      options: await _authHeaders(),
    );
  }

  Future<void> asignarTodasLasObras(
      String perfilId, List<int> obraIds) async {
    final token = await _authService.getToken();
    await _dio.post(
      '/asignaciones/asignar_obras_batch/$perfilId',
      data: obraIds,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  // Partes
  // ─────────────────────────────────────────

  Future<List<dynamic>> getPartes() async {
    final response = await _dio.get(
      '/partes/get_partes',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  Future<List<dynamic>> getPartesJefe() async {
    final response = await _dio.get(
      '/partes/get_partes_jefe',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
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

  Future<void> updateParteJefe(int parteId, Map<String, dynamic> data) async {
    try {
      await _dio.put(
        '/partes/update_parte_jefe/$parteId',
        data: data,
        options: await _authHeaders(),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data?.toString() ?? 'Error al actualizar el parte';
      }
      rethrow;
    }
  }

  Future<void> eliminarParte(int id) async {
    try {
      await _dio.delete('/partes/delete/$id', options: await _authHeaders());
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data?.toString() ?? 'Error al eliminar el parte';
      }
      rethrow;
    }
  }

  Future<void> deleteParteJefe(dynamic id) async {
    try {
      await _dio.delete(
        '/partes/delete_jefe/$id',
        options: await _authHeaders(),
      );
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data?.toString() ??
            'Error al eliminar el parte de jefe';
      }
      rethrow;
    }
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
    return (response.data as List?) ?? [];
  }

  Future<Map<String, dynamic>> getParteById(int id) async {
    final response = await _dio.get(
      '/partes/$id',
      options: await _authHeaders(),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getResumenMensualJefe(int anio, int mes) async {
    final response = await _dio.get(
      '/partes/resumen-mensual-jefe',
      queryParameters: {'anio': anio, 'mes': mes},
      options: await _authHeaders(),
    );
    return response.data as Map<String, dynamic>;
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
  // Fecha libre — gestión de días permitidos
  // ─────────────────────────────────────────

  Future<void> habilitarFechas(String id, List<DateTime> fechas) async {
    final body = fechas.map(_fmtDate).toList();
    await _dio.post(
      '/config/fecha-libre/habilitar/$id',
      data: body,
      options: Options(
        headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
        contentType: 'application/json',
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
  // Quincena
  // ─────────────────────────────────────────

  Future<List<dynamic>> getQuincena(String desde, String hasta) async {
    final response = await _dio.get(
      '/quincena',
      queryParameters: {'desde': desde, 'hasta': hasta},
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
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
        'quincena_${desde}_$hasta.xlsx',
      );
    }
  }

  Future<List<dynamic>> getContabilidadDetalleJson(
    DateTime desde,
    DateTime hasta,
  ) async {
    final response = await _dio.get(
      '/quincena/contabilidad-detalle-json',
      queryParameters: {'desde': _fmtDate(desde), 'hasta': _fmtDate(hasta)},
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
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
          'detalle_contabilidad_${desdeStr}_$hastaStr.xlsx',
        );
      }
    } catch (e) {
      throw 'Error al exportar CSV detallado: $e';
    }
  }

  Future<List<dynamic>> getContabilidadDetalleJsonJefe(
    DateTime desde,
    DateTime hasta,
  ) async {
    final response = await _dio.get(
      '/quincena/jefe/contabilidad-detalle-json',
      queryParameters: {'desde': _fmtDate(desde), 'hasta': _fmtDate(hasta)},
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  Future<void> exportarContabilidadDetalleCsvJefe(
    DateTime desde,
    DateTime hasta,
  ) async {
    final desdeStr = _fmtDate(desde);
    final hastaStr = _fmtDate(hasta);
    try {
      final response = await _dio.get(
        '/quincena/jefe/exportar-detalle-csv',
        queryParameters: {'desde': desdeStr, 'hasta': hastaStr},
        options: Options(
          headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
          responseType: ResponseType.bytes,
        ),
      );
      if (response.data != null) {
        saveAndLaunchFile(
          Uint8List.fromList(response.data),
          'detalle_obras_${desdeStr}_$hastaStr.xlsx',
        );
      }
    } catch (e) {
      throw 'Error al exportar CSV: $e';
    }
  }

  // ─────────────────────────────────────────
  // Ausencias — incidencias
  // ─────────────────────────────────────────

  Future<Map<String, dynamic>> getDiasSinParte() async {
    final response = await _dio.get(
      '/ausencias/dias-sin-parte',
      options: await _authHeaders(),
    );
    return response.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────
  // Ausencias laborales — baja / vacaciones
  // ─────────────────────────────────────────

  Future<Map<String, dynamic>> crearAusenciaLaboral({
    required String perfilId,
    required String tipo,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? observaciones,
    int? obraId,
  }) async {
    try {
      final response = await _dio.post(
        '/ausencias/laborales',
        data: {
          'perfil_id': perfilId,
          'tipo': tipo,
          'fecha_inicio': _fmtDate(fechaInicio),
          'fecha_fin': _fmtDate(fechaFin),
          if (observaciones != null) 'observaciones': observaciones,
          if (obraId != null) 'obra_id': obraId,
        },
        options: await _authHeaders(),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw e.response?.data?.toString() ?? 'Error al crear la ausencia';
    }
  }

  Future<void> eliminarAusenciaLaboral(int id) async {
    try {
      await _dio.delete(
        '/ausencias/laborales/$id',
        options: await _authHeaders(),
      );
    } on DioException catch (e) {
      throw e.response?.data?.toString() ?? 'Error al eliminar la ausencia';
    }
  }

  Future<List<dynamic>> getAusenciasLaboralesDePerfil(String perfilId) async {
    final response = await _dio.get(
      '/ausencias/laborales/perfil/$perfilId',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  // ─────────────────────────────────────────
  // PDF / ZIP de partes
  // ─────────────────────────────────────────

  Map<String, dynamic> _buildPdfParams(
    DateTime desde,
    DateTime hasta,
    List<int> obraIds,
    List<String> perfilIds,
  ) {
    return <String, dynamic>{
      'desde': _fmtDate(desde),
      'hasta': _fmtDate(hasta),
      if (obraIds.isNotEmpty) 'obraIds': obraIds,
      if (perfilIds.isNotEmpty) 'perfilIds': perfilIds,
    };
  }

  Future<Uint8List> generarPdfPartes({
    required DateTime desde,
    required DateTime hasta,
    List<int> obraIds = const [],
    List<String> perfilIds = const [],
  }) async {
    final response = await _dio.get(
      '/pdf/partes',
      queryParameters: _buildPdfParams(desde, hasta, obraIds, perfilIds),
      options: Options(
        headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
        responseType: ResponseType.bytes,
        listFormat: ListFormat.multi,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  Future<Uint8List> generarZipPartes({
    required DateTime desde,
    required DateTime hasta,
    List<int> obraIds = const [],
    List<String> perfilIds = const [],
  }) async {
    final response = await _dio.get(
      '/pdf/partes-zip',
      queryParameters: _buildPdfParams(desde, hasta, obraIds, perfilIds),
      options: Options(
        headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
        responseType: ResponseType.bytes,
        listFormat: ListFormat.multi,
      ),
    );
    return Uint8List.fromList(response.data);
  }

  void guardarPdfLocal(Uint8List bytes, String nombre) {
    saveAndLaunchFile(bytes, nombre);
  }

  Future<Uint8List> generarZipPartesPorOperario({
    required DateTime desde,
    required DateTime hasta,
    List<int> obraIds = const [],
    List<String> perfilIds = const [],
  }) async {
    final params = _buildPdfParams(desde, hasta, obraIds, perfilIds);
    final response = await _dio.get<List<int>>(
      '/pdf/zip-por-operario',
      queryParameters: params,
      options: Options(
        headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
        responseType: ResponseType.bytes,
      ),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<Map<String, dynamic>> getInformeParteJefePorRango({
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    final response = await _dio.get(
      '/partes/informe-jefe-rango',
      queryParameters: {
        'desde': _fmtDate(fechaInicio),
        'hasta': _fmtDate(fechaFin),
      },
      options: await _authHeaders(),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getResumenMensualPorJefe(int anio, int mes) async {
    final response = await _dio.get(
      '/partes/resumen-mensual-por-usuario',
      queryParameters: {'anio': anio, 'mes': mes},
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }
Future<Map<String, dynamic>> getHistorialAusencias(String perfilId) async {
  final response = await _dio.get('/ausencias/laborales/perfil/$perfilId/historial');
  return response.data as Map<String, dynamic>;
}
  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
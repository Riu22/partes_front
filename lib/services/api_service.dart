// =============================================================================
// api_service.dart  --  Servicio central de comunicacion HTTP con el backend
// =============================================================================
// PROPOSITO:
//   Este archivo define ApiService, la unica puerta de entrada para todas las
//   llamadas a la API REST del servidor. Actua como un "cartero digital": cada
//   metodo representa un sobre queviaja al backend con instrucciones especificas
//   (GET, POST, PUT, DELETE).
//
// ANALOGIA:
//   - ApiService es como una central de correos. Cada metodo (getUsuarios,
//     crearParte, etc.) es una ruta de reparto diferente. El cartero (Dio) lleva
//     cada sobre a su direccion (endpoint) y trae la respuesta de vuelta.
//   - El interceptor de tokens es como un guardia de seguridad que revisa si el
//     pase (JWT) sigue vigente. Si el pase expiro (codigo 401), el guardia corre
//     a renovarlo automaticamente antes de que el cartero intente de nuevo.
//   - Sin este servicio, la app no podria comunicarse con el servidor: es el
//     puente entre la interfaz de usuario y la base de datos remota.
//
// CONEXION CON EL RESTO DE LA APP:
//   - Los ViewModels (ChangeNotifiers) y pantallas llaman a ApiService para
//     obtener o enviar datos. Por ejemplo, ParteTrabajoScreen usa ApiService
//     para crear, editar y eliminar partes de trabajo.
//   - AuthService se inyecta aqui para gestionar tokens. Cuando expira el
//     access_token, el interceptor de ApiService llama a AuthService.refrescarToken().
//   - Los helpers como download_helper.dart se usan para guardar archivos
//     (PDF/ZIP) descargados via ApiService.
// =============================================================================

import 'package:dio/dio.dart';
import 'auth_service.dart';
import '../config/env.dart';
import '../models/parte_trabajo.dart';
import 'dart:typed_data';
import '../helpers/download_helper.dart';

/// Servicio principal de comunicacion con el backend via HTTP (Dio).
/// Centraliza todas las llamadas a la API REST: usuarios, obras, partes, PDFs, etc.
/// Incluye un interceptor que refresca automaticamente el token JWT cuando expira (codigo 401).
///
/// JWT (JSON Web Token):
///   Es un pase digital con formato `header.payload.firma`. El servidor genera
///   este token cuando el usuario inicia sesion. Cada peticion HTTP debe incluir
///   el token en el header `Authorization: Bearer <token>` para demostrar que
///   el usuario esta autenticado.
///
/// FLUJO DE RENOVACION:
///   1. El interceptor detecta una respuesta 401 (no autorizado).
///   2. Verifica que no se este ya renovando (_refrescando) y que no sea un
///      reintento previo (extra['retried']).
///   3. Pide un nuevo token a AuthService.refrescarToken().
///   4. Si obtiene un token nuevo, actualiza el header de la peticion original
///      y la reintenta (handler.resolve).
///   5. Si falla la renovacion, deja que el error original fluya (handler.next).
class ApiService {
  /// Instancia de Dio: el "cartero" que ejecuta las peticiones HTTP.
  /// Se configura con url base, timeouts e interceptores.
  late final Dio _dio;

  /// Referencia a AuthService para obtener/renovar tokens JWT.
  /// Se inyecta desde fuera (patron de dependencia) o se crea automaticamente.
  final AuthService _authService;

  /// Bandera "mutex" para evitar que multiples errores 401 simultaneos
  /// disparen varias renovaciones de token a la vez. Solo un hilo puede
  /// renovar el token en un momento dado.
  bool _refrescando = false;

  /// Constructor. Recibe un AuthService opcional (si no se pasa, crea uno nuevo).
  /// Configura Dio con la URL base desde Env.apiUrl y establece timeouts de
  /// 15 segundos para conexion, recepcion y envio.
  ApiService([AuthService? authService])
    : _authService = authService ?? AuthService() {
    // Inicializa el cliente HTTP con la configuracion base
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    // =====================================================================
    // INTERCEPTOR DE RENOVACION AUTOMATICA DE TOKENS
    // =====================================================================
    // Explicacion detallada del mecanismo:
    //
    //   onError se ejecuta cuando CUALQUIER peticion HTTP falla. Aqui solo
    //   nos interesan los errores 401 (Unauthorized), que indican que el
    //   token JWT ha expirado o es invalido.
    //
    //   Hay dos salvaguardas para evitar bucles infinitos:
    //     1. _refrescando: booleano que actua como semaforo. Si ya estamos
    //        renovando el token, ignoramos cualquier otro 401. Esto evita
    //        que multiples peticiones fallidas intenten renovar a la vez.
    //     2. extra['retried']: marcamos la peticion original con un flag
    //        para saber que ya fue reintentada. Si vuelve a dar 401 despues
    //        del reintento, significa que el refresh token tambien expiro.
    //
    //   Flujo completo:
    //     Peticion A -> 401 -> interceptor ve 401, _refrescando=false,
    //     retried=false -> marca _refrescando=true -> llama refrescarToken()
    //     -> obtiene nuevo token -> clona peticion A con nuevo token y
    //     retried=true -> handler.resolve (reintenta) -> si ok, devuelve
    //     respuesta; si vuelve 401, handler.next (falla definitivo).
    //
    //   handler.resolve vs handler.next:
    //     - resolve: "resuelve" el error (lo convierte en respuesta exitosa)
    //     - next: deja que el error siga su curso normal hacia el catch
    // =====================================================================
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          // Solo nos interesan errores 401 (No autorizado / token expirado)
          final is401 = error.response?.statusCode == 401;

          // Verifica si esta peticion ya fue reintentada una vez
          final yaReintentado = error.requestOptions.extra['retried'] == true;

          // Condicion compuesta: es 401, NO se ha reintentado antes,
          // y NO estamos ya en medio de una renovacion
          if (is401 && !yaReintentado && !_refrescando) {
            // Activa el semaforo para evitar renovaciones concurrentes
            _refrescando = true;

            // Pide un token fresco a AuthService (usa el refresh_token guardado)
            final nuevoToken = await _authService.refrescarToken();

            // Libera el semaforo inmediatamente despues del intento
            _refrescando = false;

            if (nuevoToken != null) {
              // Clona las opciones de la peticion original pero con el nuevo
              // token en el header Authorization
              final opts = error.requestOptions
                ..headers['Authorization'] = 'Bearer $nuevoToken'
                ..extra['retried'] = true; // Marca como reintentado

              try {
                // Reintenta la peticion original con el nuevo token
                final response = await _dio.fetch(opts);
                // Convierte el error en una respuesta exitosa
                return handler.resolve(response);
              } catch (e) {
                // Si el reintento tambien falla, deja pasar el error original
                return handler.next(error);
              }
            }
          }

          // Si no se cumplen las condiciones, dejar que el error fluya
          handler.next(error);
        },
      ),
    );
  }

  /// Anade el token JWT a los headers de la peticion para autenticacion.
  /// Lee el token desde AuthService (que a su vez lo obtiene del
  /// almacenamiento seguro o de la memoria cache).
  /// Devuelve un objeto Options con el header Authorization: Bearer <token>.
  Future<Options> _authHeaders() async {
    final token = await _authService.getToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // =====================================================================
  // PERFIL DEL USUARIO
  // =====================================================================

  /// Obtiene el perfil del usuario actualmente autenticado.
  /// Endpoint: GET /user/me
  /// Devuelve un mapa con datos como nombre, email, rol, etc.
  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _dio.get('/user/me', options: await _authHeaders());
    return response.data;
  }

  // =====================================================================
  // USUARIOS (CRUD)
  // =====================================================================

  /// Obtiene la lista completa de usuarios registrados en el sistema.
  /// Endpoint: GET /user/all
  /// Devuelve una lista de mapas, cada uno representa un usuario.
  Future<List<dynamic>> getUsuarios() async {
    final response = await _dio.get('/user/all', options: await _authHeaders());
    return (response.data as List?) ?? [];
  }

  /// Crea un nuevo usuario en el sistema.
  /// Endpoint: POST /user/create_user
  /// [data] debe contener los campos requeridos (email, password, nombre, rol, etc.)
  Future<void> crearUsuario(Map<String, dynamic> data) async {
    await _dio.post(
      '/user/create_user',
      data: data,
      options: await _authHeaders(),
    );
  }

  /// Edita un usuario existente identificado por su [id].
  /// Endpoint: PUT /user/update_user/$id
  /// [data] contiene solo los campos a modificar.
  Future<void> editarUsuario(String id, Map<String, dynamic> data) async {
    await _dio.put(
      '/user/update_user/$id',
      data: data,
      options: await _authHeaders(),
    );
  }

  /// Elimina un usuario del sistema por su [id].
  /// Endpoint: DELETE /user/delete_user/$id
  Future<void> eliminarUsuario(String id) async {
    await _dio.delete('/user/delete_user/$id', options: await _authHeaders());
  }

  // =====================================================================
  // OBRAS (CRUD)
  // =====================================================================

  /// Obtiene todas las obras registradas (activas e inactivas).
  /// Endpoint: GET /obra
  Future<List<dynamic>> getObras() async {
    final response = await _dio.get('/obra', options: await _authHeaders());
    return (response.data as List?) ?? [];
  }

  /// Obtiene solo las obras marcadas como activas en el sistema.
  /// Endpoint: GET /obra/activas
  Future<List<dynamic>> getObrasActivas() async {
    final response = await _dio.get(
      '/obra/activas',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  /// Crea una nueva obra con los datos proporcionados.
  /// Endpoint: POST /obra
  /// Incluye manejo de errores: si el servidor responde con un mensaje de error,
  /// lo extrae y lo lanza. Si no hay respuesta, lanza un mensaje generico.
  Future<void> crearObra(Map<String, dynamic> data) async {
    try {
      await _dio.post('/obra', data: data, options: await _authHeaders());
    } on DioException catch (e) {
      if (e.response != null) {
        throw e.response?.data.toString() ?? 'Error en el servidor';
      }
      throw 'Error de conexion inesperado';
    }
  }

  /// Actualiza los datos de una obra existente.
  /// Endpoint: PUT /obra/update_obra/$id
  Future<void> editarObra(int id, Map<String, dynamic> data) async {
    await _dio.put(
      '/obra/update_obra/$id',
      data: data,
      options: await _authHeaders(),
    );
  }

  /// Elimina una obra del sistema por su [id].
  /// Endpoint: DELETE /obra/delete/$id
  Future<void> eliminarObra(int id) async {
    await _dio.delete('/obra/delete/$id', options: await _authHeaders());
  }

  // =====================================================================
  // ASIGNACIONES (operarios <-> jefes, operarios <-> obras)
  // =====================================================================

  /// Obtiene la lista de subordinados (operarios) asignados a un jefe.
  /// Endpoint: GET /asignaciones/$jefeId/subordinados
  Future<List<dynamic>> getSubordinadosDe(String jefeId) async {
    final response = await _dio.get(
      '/asignaciones/$jefeId/subordinados',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  /// Asigna un operario (subordinado) a un jefe.
  /// Endpoint: PUT /asignaciones/asignar_subordinado/$subordinadoId/$jefeId
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

  /// Elimina la relacion jefe-subordinado de un usuario.
  /// Endpoint: DELETE /asignaciones/quitar_subordinado/$usuarioId
  Future<void> quitarSubordinado(String usuarioId) async {
    await _dio.delete(
      '/asignaciones/quitar_subordinado/$usuarioId',
      options: await _authHeaders(),
    );
  }

  /// Obtiene todas las asignaciones de operarios a una obra especifica.
  /// Endpoint: GET /asignaciones/obra/$obraId
  Future<List<dynamic>> getAsignacionesObra(int obraId) async {
    final response = await _dio.get(
      '/asignaciones/obra/$obraId',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  /// Asigna un perfil (operario/jefe) a una obra.
  /// Endpoint: POST /asignaciones/asignar_a_obra/$perfilId/$obraId
  Future<void> asignarAObra(String perfilId, int obraId) async {
    await _dio.post(
      '/asignaciones/asignar_a_obra/$perfilId/$obraId',
      options: await _authHeaders(),
    );
  }

  /// Elimina una asignacion de obra por su ID.
  /// Endpoint: DELETE /asignaciones/eliminar/$asignacionId
  Future<void> eliminarAsignacionObra(int asignacionId) async {
    await _dio.delete(
      '/asignaciones/eliminar/$asignacionId',
      options: await _authHeaders(),
    );
  }

  /// Obtiene las obras asignadas al usuario autenticado.
  /// Endpoint: GET /asignaciones/mis_obras
  Future<List<dynamic>> getMisObras() async {
    final response = await _dio.get(
      '/asignaciones/mis_obras',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  /// Obtiene las obras asignadas a un perfil especifico.
  /// Endpoint: GET /asignaciones/perfil/$perfilId
  Future<List<dynamic>> getObrasDePerfil(String perfilId) async {
    final response = await _dio.get(
      '/asignaciones/perfil/$perfilId',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  /// Asigna multiples subordinados a un jefe en una sola llamada (batch).
  /// Endpoint: PUT /asignaciones/asignar_subordinados_batch/$jefeId
  /// [subordinadoIds] es una lista de IDs de usuarios a asignar.
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

  /// Asigna un perfil a una obra (version alternativa de asignarAObra).
  /// Endpoint: POST /asignaciones/asignar_a_obra/$perfilId/$obraId
  Future<void> asignarPerfilAObra(String perfilId, int obraId) async {
    await _dio.post(
      '/asignaciones/asignar_a_obra/$perfilId/$obraId',
      options: await _authHeaders(),
    );
  }

  /// Asigna un perfil a multiples obras en una sola llamada (batch).
  /// Endpoint: POST /asignaciones/asignar_obras_batch/$perfilId
  /// [obraIds] es una lista de IDs de obras a asignar.
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

  // =====================================================================
  // PARTES DE TRABAJO (CRUD)
  // =====================================================================

  /// Obtiene todos los partes de trabajo (para operarios).
  /// Endpoint: GET /partes/get_partes
  Future<List<dynamic>> getPartes() async {
    final response = await _dio.get(
      '/partes/get_partes',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  /// Obtiene todos los partes de trabajo creados por jefes de obra.
  /// Endpoint: GET /partes/get_partes_jefe
  Future<List<dynamic>> getPartesJefe() async {
    final response = await _dio.get(
      '/partes/get_partes_jefe',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  /// Crea un nuevo parte de trabajo (operario).
  /// Endpoint: POST /partes/new_parte
  /// [data] contiene los campos del parte (fecha, obra, horas, etc.)
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

  /// Crea un nuevo parte de trabajo (jefe de obra).
  /// Endpoint: POST /partes/new_parte_jefe
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

  /// Actualiza un parte de trabajo existente (operario).
  /// Endpoint: PUT /partes/update/$parteId
  /// Devuelve el objeto ParteTrabajo actualizado (desde la respuesta JSON).
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

  /// Actualiza un parte de trabajo existente (jefe de obra).
  /// Endpoint: PUT /partes/update_parte_jefe/$parteId
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

  /// Elimina un parte de trabajo (operario) por su ID.
  /// Endpoint: DELETE /partes/delete/$id
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

  /// Elimina un parte de trabajo (jefe de obra) por su ID.
  /// Endpoint: DELETE /partes/delete_jefe/$id
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

  /// Busca partes de trabajo aplicando filtros opcionales.
  /// Endpoint: GET /partes/buscar
  /// [obra]: filtra por nombre de obra
  /// [operario]: filtra por nombre de operario
  /// [especialidad]: filtra por especialidad del operario
  /// Solo incluye en la query los parametros que no esten vacios.
  Future<List<dynamic>> buscarPartes({
    String? obra,
    String? operario,
    String? especialidad,
  }) async {
    // Construye el mapa de parametros solo con los filtros proporcionados
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

  /// Obtiene un parte de trabajo por su ID.
  /// Endpoint: GET /partes/$id
  Future<Map<String, dynamic>> getParteById(int id) async {
    final response = await _dio.get(
      '/partes/$id',
      options: await _authHeaders(),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Obtiene el resumen mensual de partes para el jefe de obra.
  /// Endpoint: GET /partes/resumen-mensual-jefe
  /// [anio] y [mes] determinan el periodo a consultar.
  Future<Map<String, dynamic>> getResumenMensualJefe(int anio, int mes) async {
    final response = await _dio.get(
      '/partes/resumen-mensual-jefe',
      queryParameters: {'anio': anio, 'mes': mes},
      options: await _authHeaders(),
    );
    return response.data as Map<String, dynamic>;
  }

  // =====================================================================
  // FECHAS CON PARTE (para el calendario / DatePicker)
  // =====================================================================

  /// Obtiene las fechas en las que el usuario autenticado tiene partes creados.
  /// Endpoint: GET /partes/mis-fechas-con-parte
  /// Devuelve una lista de objetos DateTime. Si hay error, retorna lista vacia.
  /// Se usa para marcar los dias con parte en el calendario visual.
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

  /// Obtiene las fechas con parte para un usuario especifico (jefe viendo a subordinado).
  /// Endpoint: GET /partes/fechas-con-parte/$id
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

  // =====================================================================
  // FECHA LIBRE -- Gestion de dias habilitados para editar partes anteriores
  // =====================================================================

  /// Habilita fechas especificas para que un usuario pueda editar partes
  /// de dias pasados (normalmente bloqueados).
  /// Endpoint: POST /config/fecha-libre/habilitar/$id
  /// [fechas] lista de DateTime a habilitar.
  Future<void> habilitarFechas(String id, List<DateTime> fechas) async {
    // Convierte las fechas a strings ISO (YYYY-MM-DD) para enviar al servidor
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

  /// Deshabilita una fecha concreta para un usuario.
  /// Endpoint: DELETE /config/fecha-libre/deshabilitar/$id/${_fmtDate(fecha)}
  Future<void> deshabilitarFecha(String id, DateTime fecha) async {
    await _dio.delete(
      '/config/fecha-libre/deshabilitar/$id/${_fmtDate(fecha)}',
      options: await _authHeaders(),
    );
  }

  /// Deshabilita todas las fechas libres de un usuario (las borra todas).
  /// Endpoint: DELETE /config/fecha-libre/deshabilitar/$id
  Future<void> deshabilitarFechaLibre(String id) async {
    await _dio.delete(
      '/config/fecha-libre/deshabilitar/$id',
      options: await _authHeaders(),
    );
  }

  /// Obtiene todas las fechas libres activas, agrupadas por usuario.
  /// Endpoint: GET /config/fecha-libre
  /// Devuelve un mapa donde las claves son IDs de usuario y los valores
  /// son listas de DateTime.
  Future<Map<String, List<DateTime>>> getFechaLibreActivos() async {
    final response = await _dio.get(
      '/config/fecha-libre',
      options: await _authHeaders(),
    );
    final raw = response.data as Map<String, dynamic>;
    // Convierte las fechas de string a DateTime para cada entrada del mapa
    return raw.map(
      (userId, fechas) => MapEntry(
        userId,
        (fechas as List).map((s) => DateTime.parse(s.toString())).toList(),
      ),
    );
  }

  /// Obtiene las fechas libres del usuario autenticado.
  /// Endpoint: GET /config/fecha-libre/mis-fechas
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

  // =====================================================================
  // QUINCENA / CONTABILIDAD
  // =====================================================================

  /// Obtiene los datos de una quincena (periodo de 15 dias) para contabilidad.
  /// Endpoint: GET /quincena
  /// [desde] y [hasta] son strings con formato YYYY-MM-DD.
  Future<List<dynamic>> getQuincena(String desde, String hasta) async {
    final response = await _dio.get(
      '/quincena',
      queryParameters: {'desde': desde, 'hasta': hasta},
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  /// Exporta los datos de una quincena a un archivo Excel (.xlsx).
  /// Endpoint: GET /quincena/exportar
  /// Descarga los bytes del archivo y lo abre con saveAndLaunchFile.
  Future<void> exportarQuincena(String desde, String hasta) async {
    final response = await _dio.get(
      '/quincena/exportar',
      queryParameters: {'desde': desde, 'hasta': hasta},
      options: Options(
        headers: {'Authorization': 'Bearer ${await _authService.getToken()}'},
        responseType: ResponseType.bytes, // Importante: recibir bytes, no JSON
      ),
    );
    if (response.data != null) {
      saveAndLaunchFile(
        Uint8List.fromList(response.data),
        'quincena_${desde}_$hasta.xlsx',
      );
    }
  }

  /// Obtiene el detalle de contabilidad en formato JSON para un rango de fechas.
  /// Endpoint: GET /quincena/contabilidad-detalle-json
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

  /// Exporta el detalle de contabilidad a un archivo Excel (.xlsx).
  /// Endpoint: GET /quincena/exportar-detalle-csv
  /// Descarga los bytes y los guarda/abre con saveAndLaunchFile.
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

  /// Obtiene el detalle de contabilidad JSON para jefes de obra.
  /// Endpoint: GET /quincena/jefe/contabilidad-detalle-json
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

  /// Exporta el detalle de contabilidad a Excel para jefes de obra.
  /// Endpoint: GET /quincena/jefe/exportar-detalle-csv
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

  // =====================================================================
  // AUSENCIAS -- Dias sin parte / incidencias
  // =====================================================================

  /// Obtiene los dias en los que el usuario NO tiene partes registrados.
  /// Endpoint: GET /ausencias/dias-sin-parte
  /// Util para detectar dias no trabajados o faltantes.
  Future<Map<String, dynamic>> getDiasSinParte() async {
    final response = await _dio.get(
      '/ausencias/dias-sin-parte',
      options: await _authHeaders(),
    );
    return response.data as Map<String, dynamic>;
  }

  // =====================================================================
  // AUSENCIAS LABORALES -- Bajas / Vacaciones / Paternidad
  // =====================================================================

  /// Crea un registro de ausencia laboral (baja, vacaciones, permiso, etc.).
  /// Endpoint: POST /ausencias/laborales
  /// [perfilId]: ID del usuario ausente.
  /// [tipo]: tipo de ausencia (baja, vacaciones, paternidad, etc.).
  /// [fechaInicio] y [fechaFin]: rango de la ausencia.
  /// [observaciones]: opcional, texto libre.
  /// [obraId]: opcional, obra asociada.
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

  /// Elimina un registro de ausencia laboral por su ID.
  /// Endpoint: DELETE /ausencias/laborales/$id
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

  /// Obtiene todas las ausencias laborales de un perfil especifico.
  /// Endpoint: GET /ausencias/laborales/perfil/$perfilId
  Future<List<dynamic>> getAusenciasLaboralesDePerfil(String perfilId) async {
    final response = await _dio.get(
      '/ausencias/laborales/perfil/$perfilId',
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  // =====================================================================
  // PDF / ZIP -- Exportacion de partes
  // =====================================================================

  /// Construye el mapa de parametros para las peticiones de generacion de PDF/ZIP.
  /// Incluye el rango de fechas y filtros opcionales de obras y perfiles.
  /// Solo anade obraIds y perfilIds si las listas no estan vacias.
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

  /// Genera un PDF con los partes de trabajo del rango de fechas y filtros.
  /// Endpoint: GET /pdf/partes
  /// Devuelve los bytes del PDF generado.
  /// Los parametros opcionales permiten filtrar por obras y/o perfiles especificos.
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
        listFormat: ListFormat.multi, // Permite arrays en query params
      ),
    );
    return Uint8List.fromList(response.data);
  }

  /// Genera un ZIP que contiene todos los PDFs de partes individuales.
  /// Endpoint: GET /pdf/partes-zip
  /// Util para descargar varios partes a la vez comprimidos.
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

  /// Guarda un PDF localmente y lo abre con la aplicacion predeterminada.
  /// Util para descargar un PDF ya generado y almacenado en memoria.
  void guardarPdfLocal(Uint8List bytes, String nombre) {
    saveAndLaunchFile(bytes, nombre);
  }

  /// Genera un ZIP que agrupa los PDFs por operario (cada operario en su carpeta).
  /// Endpoint: GET /pdf/zip-por-operario
  /// Util para distribuir los partes a cada trabajador.
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

  /// Obtiene un informe de partes de jefe de obra para un rango de fechas.
  /// Endpoint: GET /partes/informe-jefe-rango
  /// Devuelve datos agregados como totales, horas, etc.
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

  /// Obtiene un resumen mensual de partes agrupado por jefe de obra.
  /// Endpoint: GET /partes/resumen-mensual-por-usuario
  /// [anio] y [mes] definen el periodo del resumen.
  Future<List<dynamic>> getResumenMensualPorJefe(int anio, int mes) async {
    final response = await _dio.get(
      '/partes/resumen-mensual-por-usuario',
      queryParameters: {'anio': anio, 'mes': mes},
      options: await _authHeaders(),
    );
    return (response.data as List?) ?? [];
  }

  /// Obtiene el historial completo de ausencias laborales de un perfil.
  /// Endpoint: GET /ausencias/laborales/perfil/$perfilId/historial
  /// Nota: esta llamada NO incluye token de autenticacion (por diseno o por omision).
  Future<Map<String, dynamic>> getHistorialAusencias(String perfilId) async {
    final response = await _dio.get('/ausencias/laborales/perfil/$perfilId/historial');
    return response.data as Map<String, dynamic>;
  }

  // =====================================================================
  // HELPERS -- Utilidades internas
  // =====================================================================

  /// Convierte un objeto DateTime a string con formato ISO YYYY-MM-DD.
  /// Ejemplo: DateTime(2024, 3, 5) -> "2024-03-05".
  /// Se usa para enviar fechas al servidor en el formato que este espera.
  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

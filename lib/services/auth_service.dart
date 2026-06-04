// =============================================================================
// auth_service.dart  --  Servicio de autenticacion contra Supabase Auth
// =============================================================================
// PROPOSITO:
//   Gestiona todo el ciclo de vida de la autenticacion: inicio de sesion,
//   cierre de sesion, renovacion de tokens, cambio de contrasena y
//   recuperacion de cuenta. Es la "oficina de identificacion digital" de la app.
//
// ANALOGIA:
//   - AuthService es como un carnet digital o pasaporte. Cuando el usuario
//     inicia sesion, recibe un "visado" (JWT) que debe presentar en cada
//     tramite (peticion HTTP). El visado tiene una fecha de caducidad
//     (access_token) y un "pase renovable" (refresh_token) para extenderlo
//     sin tener que volver a hacer la cola (escribir email y password otra vez).
//   - FlutterSecureStorage es como una caja fuerte biometrica: los tokens se
//     guardan cifrados en el dispositivo (Keychain en iOS, EncryptedSharedPrefs
//     en Android). Nadie puede leerlos sin la clave del sistema.
//   - _tokenCache es como una nota adhesiva en el escritorio: evita tener que
//     abrir la caja fuerte cada vez que se necesita el token.
//
// CONEXION CON EL RESTO DE LA APP:
//   - ApiService inyecta AuthService para anadir el token JWT a cada peticion
//     y para refrescarlo automaticamente cuando expira (ver interceptor en
//     api_service.dart).
//   - Las pantallas de login y recuperacion de password llaman a AuthService
//     directamente.
//   - Otras pantallas (perfil, cambio de email/password) usan AuthService
//     para operaciones de cuenta.
//
// TOKENS JWT: EXPLICACION DETALLADA
//   JWT = JSON Web Token. Es un string con tres partes separadas por puntos:
//     HEADER.PAYLOAD.FIRMA
//   - HEADER: contiene el algoritmo usado (ej: HS256) y el tipo de token.
//   - PAYLOAD: contiene los "claims" (datos), como user_id, email, y exp
//     (fecha de expiracion en timestamp Unix). El payload esta codificado en
//     base64url, NO cifrado. Cualquiera puede decodificarlo y leerlo.
//   - FIRMA: el servidor genera la firma con una clave secreta. Si alguien
//     modifica el header o el payload, la firma deja de ser valida.
//
//   RENOVACION DE TOKENS:
//   El access_token dura poco (tipicamente 1 hora). El refresh_token dura
//   mas (dias o meses). Cuando el access_token expira, el interceptor de
//   ApiService llama a refrescarToken(), que envia el refresh_token a
//   Supabase para obtener un par nuevo (access_token + refresh_token).
//   El usuario ni se entera de que el token caduco.
//
//   ALMACENAMIENTO SEGURO:
//   FlutterSecureStorage cifra los datos a nivel de SO:
//   - Android: usa EncryptedSharedPreferences (AES-256 con key en el
//     Android Keystore).
//   - iOS: usa el Keychain de iOS (AES-256).
//   Los tokens jamas deben guardarse en SharedPreferences ni en texto plano.
// =============================================================================

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env.dart';
import '../helpers/url_helper.dart';

/// Servicio de autenticacion: login, logout, refresh de token, cambio de contrasena.
/// Usa Supabase Auth como backend y guarda los tokens en almacenamiento seguro.
///
/// ESTRUCTURA DEL TOKEN JWT (ejemplo decodificado):
///   Header:  {"alg":"HS256","typ":"JWT"}
///   Payload: {"sub":"user_uuid","email":"user@ej.com","exp":1700000000,...}
///   Firma:   <HMAC-SHA256(base64(header).base64(payload), secreto)>
///
/// METODO DE RENOVACION:
///   Cuando el access_token expira, se envia el refresh_token a:
///   POST /auth/v1/token?grant_type=refresh_token
///   El servidor devuelve un nuevo par (access_token + refresh_token).
class AuthService {
  /// Cliente HTTP ligero para comunicarse con la API de Supabase Auth.
  /// Se usa solo para login, refresh y cambios de cuenta (no para datos de la app).
  final Dio _dio = Dio();

  /// Almacenamiento seguro cifrado a nivel de sistema operativo.
  /// Guarda el access_token (jwt), refresh_token y perfil del usuario.
  /// Equivalente a una caja fuerte digital.
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Cache del token JWT en memoria (RAM).
  /// Evita leer del almacenamiento seguro (disco) en cada peticion,
  /// lo cual es mas rapido pero menos seguro (el token vive en RAM).
  /// Se limpia al hacer logout.
  String? _tokenCache;

  /// Obtiene la clave "anon key" de Supabase desde la configuracion.
  /// Esta clave es publica y se usa como identificador de proyecto en las
  /// peticiones a la API de auth. No es secreta.
  String get _anonKey => Env.supabaseAnonKey;

  /// Inicia sesion con email y contrasena contra Supabase Auth.
  /// Devuelve el access_token si OK, o null si falla.
  ///
  /// Endpoint: POST {supabaseUrl}/auth/v1/token?grant_type=password
  /// Envia las credenciales al servidor. Si son validas, el servidor devuelve
  /// un access_token (JWT) y un refresh_token.
  ///
  /// [email] y [password] son las credenciales del usuario.
  Future<String?> login(String email, String password) async {
    try {
      // Peticion a Supabase Auth con las credenciales
      final response = await _dio.post(
        '${Env.supabaseUrl}/auth/v1/token?grant_type=password',
        data: {'email': email, 'password': password},
        options: Options(
          headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
        ),
      );

      // Guarda el access_token y refresh_token en almacenamiento seguro y cache
      await _guardarSesion(response.data);

      // Devuelve solo el access_token para uso inmediato
      return response.data['access_token'];
    } on DioException catch (e) {
      _handleError(e);
      return null;
    } catch (e, stackTrace) {
      // Captura errores no relacionados con Dio (ej: error de parsing)
      debugPrint('Error inesperado en login: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Guarda el access_token y refresh_token en el almacenamiento seguro.
  /// Tambien los guarda en cache en memoria para acceso rapido.
  ///
  /// [data] es el mapa devuelto por Supabase que contiene:
  ///   - access_token: el JWT que se envia en cada peticion
  ///   - refresh_token: token de larga duracion para renovar el access_token
  ///   - user: datos del usuario (opcional)
  Future<void> _guardarSesion(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String?;

    // Guarda el access_token en la caja fuerte (disco cifrado)
    await _storage.write(key: 'jwt', value: accessToken);

    // Guarda el refresh_token si existe (puede no venir en algunas respuestas)
    if (refreshToken != null) {
      await _storage.write(key: 'refresh_token', value: refreshToken);
    }

    // Actualiza la cache en memoria para acceso inmediato
    _tokenCache = accessToken;
  }

  /// Intenta renovar el token JWT usando el refresh_token guardado.
  /// Si el refresh tambien falla, hace logout automatico.
  ///
  /// Endpoint: POST {supabaseUrl}/auth/v1/token?grant_type=refresh_token
  ///
  /// El refresh_token es un token de larga duracion (ej: 30 dias) que permite
  /// obtener un nuevo par access_token + refresh_token sin que el usuario
  /// tenga que escribir su email y contrasena de nuevo.
  ///
  /// Flujo tipico de renovacion:
  ///   1. access_token caduca (tipicamente a la hora).
  ///   2. Interceptor de ApiService detecta 401 y llama a este metodo.
  ///   3. Se envia el refresh_token a Supabase.
  ///   4. Supabase devuelve un nuevo access_token y un nuevo refresh_token.
  ///   5. Los nuevos tokens se guardan en almacenamiento seguro.
  ///
  /// Si el refresh_token tambien expiro (o fue revocado), se llama a logout()
  /// para limpiar todo y forzar al usuario a iniciar sesion de nuevo.
  Future<String?> refrescarToken() async {
    // Lee el refresh_token desde el almacenamiento seguro
    final refreshToken = await _storage.read(key: 'refresh_token');

    // Si no hay refresh_token guardado, no se puede renovar
    if (refreshToken == null) return null;

    try {
      // Envia el refresh_token a Supabase para obtener uno nuevo
      final response = await _dio.post(
        '${Env.supabaseUrl}/auth/v1/token?grant_type=refresh_token',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'apikey': _anonKey, 'Content-Type': 'application/json'},
        ),
      );

      // Guarda el nuevo par de tokens (reemplaza los viejos)
      await _guardarSesion(response.data);

      // Devuelve el nuevo access_token
      return response.data['access_token'];
    } catch (e) {
      // Si la renovacion falla (refresh_token invalido/expirado), cierra sesion
      await logout();
      return null;
    }
  }

  /// Comprueba si un JWT ha expirado examinando su payload (campo 'exp').
  ///
  /// COMO FUNCIONA:
  ///   Un JWT tiene tres partes separadas por puntos: header.payload.firma.
  ///   La segunda parte (payload) contiene los datos del token, incluyendo
  ///   el campo 'exp' (expiration) que es un timestamp Unix (segundos desde 1970).
  ///
  ///   Este metodo:
  ///   1. Divide el JWT por los puntos.
  ///   2. Decodifica la segunda parte (payload) de base64url a texto.
  ///   3. Parsea el texto como JSON y extrae el campo 'exp'.
  ///   4. Convierte 'exp' (segundos) a DateTime.
  ///   5. Compara con la hora actual (con un margen de 30 segundos).
  ///
  ///   El margen de 30 segundos evita problemas de sincronizacion de reloj
  ///   entre el cliente y el servidor.
  ///
  /// [jwt] es el token JWT completo (header.payload.firma).
  /// Devuelve true si el token ha expirado o es invalido.
  bool tokenExpirado(String jwt) {
    try {
      // Divide el JWT en sus tres partes
      final parts = jwt.split('.');
      if (parts.length != 3) return true; // Formato invalido

      // Extrae el payload (segunda parte)
      final payload = parts[1];

      // Normaliza la cadena base64url (anade padding si es necesario)
      final normalized = base64Url.normalize(payload);

      // Decodifica de base64url a bytes y luego a string UTF-8
      final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));

      // Extrae el campo 'exp' (timestamp Unix en segundos)
      final exp = decoded['exp'] as int?;
      if (exp == null) return true;

      // Convierte el timestamp a DateTime (multiplica por 1000 para ms)
      final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);

      // Compara con la hora actual, restando 30 segundos de margen
      // Si la hora actual supera (expDate - 30s), el token esta expirado
      return DateTime.now().isAfter(expDate.subtract(const Duration(seconds: 30)));
    } catch (_) {
      // Si hay cualquier error en el proceso, asumir que el token esta expirado
      return true;
    }
  }

  /// Guarda un token JWT en el almacenamiento seguro y en cache.
  /// Util para cuando se obtiene un token por otros medios (ej: recuperacion).
  Future<void> guardarToken(String token) async {
    await _storage.write(key: 'jwt', value: token);
    _tokenCache = token;
  }

  /// Guarda un refresh_token en el almacenamiento seguro.
  /// Independiente de guardarToken para permitir guardarlos por separado.
  Future<void> guardarRefreshToken(String token) async {
    await _storage.write(key: 'refresh_token', value: token);
  }

  /// Lee el token JWT guardado (primero de cache, luego de disco).
  ///
  /// ESTRATEGIA DE LECTURA:
  ///   1. Primero intenta leer de la memoria cache (_tokenCache).
  ///      Si esta ahi, es inmediato (sin esperar a disco).
  ///   2. Si no esta en cache, lee del almacenamiento seguro (disco).
  ///   3. Actualiza la cache con el valor leido de disco.
  ///
  /// Esta estrategia balancea velocidad (cache) con seguridad (disco cifrado).
  Future<String?> getToken() async {
    _tokenCache = await _storage.read(key: 'jwt');
    return _tokenCache;
  }

  /// Guarda el perfil del usuario en almacenamiento local para uso offline.
  /// El perfil se serializa a JSON y se guarda en la caja fuerte.
  /// Permite mostrar datos del usuario incluso sin conexion a internet.
  Future<void> guardarPerfilLocal(Map<String, dynamic> perfil) async {
    await _storage.write(key: 'perfil', value: jsonEncode(perfil));
  }

  /// Recupera el perfil guardado localmente (para modo offline).
  /// Lee el JSON del almacenamiento seguro y lo deserializa a mapa.
  /// Si no hay perfil guardado, devuelve null.
  Future<Map<String, dynamic>?> getPerfilLocal() async {
    final raw = await _storage.read(key: 'perfil');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Cambia el email del usuario autenticado.
  /// Endpoint: PUT {supabaseUrl}/auth/v1/user
  /// Requiere el access_token actual (el usuario debe estar logueado).
  /// [nuevoEmail] es la nueva direccion de email que se desea asignar.
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

  /// Cierra sesion: borra token, refresh token y perfil local.
  ///
  /// Acciones que realiza:
  ///   1. Limpia la cache en memoria (_tokenCache = null).
  ///   2. Elimina TODOS los datos del almacenamiento seguro (deleteAll).
  ///      Esto borra el JWT, refresh_token, perfil local y cualquier otra
  ///      clave que se hubiera guardado con FlutterSecureStorage.
  ///
  /// NOTA: No se invalida el token en el servidor. El token simplemente se
  /// descarta del cliente. Si alguien lo interceptara, aun podria usarlo
  /// hasta que expire. Para mayor seguridad se podria anadir una llamada
  /// de cierre de sesion al servidor.
  Future<void> logout() async {
    _tokenCache = null;
    await _storage.deleteAll();
  }

  /// Cambia la contrasena del usuario autenticado.
  /// Endpoint: PUT {supabaseUrl}/auth/v1/user
  /// Requiere el access_token actual.
  /// [nuevaPassword] es la nueva contrasena a establecer.
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

  /// Cambia la contrasena usando un token de recuperacion (no requiere sesion activa).
  ///
  /// Este metodo se usa cuando el usuario hace clic en el enlace de
  /// "olvide mi contrasena" del email de recuperacion. El enlace contiene
  /// un token en la URL que permite cambiar la contrasena sin estar logueado.
  ///
  /// [token] es el token de recuperacion extraido de la URL.
  /// [nuevaPassword] es la nueva contrasena deseada.
  Future<void> cambiarPasswordConToken(String token, String nuevaPassword) async {
    debugPrint('Token usado para cambio password: ${token.substring(0, 20)}...');
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

  /// Solicita un email de recuperacion de contrasena.
  ///
  /// Endpoint: POST {supabaseUrl}/auth/v1/recover
  /// Envia un email al [email] proporcionado con un enlace magico.
  /// El enlace contiene un token de recuperacion en el fragmento de la URL
  /// (despues de #) que permite resetear la contrasena sin estar autenticado.
  ///
  /// [redirect_to] indica a que URL debe redirigir el enlace del email.
  /// En este caso redirige a la pantalla de nueva contrasena en la app web.
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
      debugPrint('Error al solicitar recuperacion: $e');
      return false;
    }
  }

  /// Extrae el token de recuperacion desde la URL del enlace magico.
  /// La URL tiene formato: app://#access_token=xxx&refresh_token=yyy&type=recovery
  ///
  /// COMO FUNCIONA:
  ///   Cuando el usuario hace clic en el enlace de recuperacion, la app recibe
  ///   una URL como: miparteapp://#access_token=abc...&refresh_token=def...&type=recovery
  ///
  ///   Los tokens vienen en el fragmento (despues de #) porque Supabase usa
  ///   el fragmento de la URL para evitar que los intermediarios (proxies,
  ///   servidores) puedan leer los tokens en los logs.
  ///
  ///   Este metodo:
  ///   1. Obtiene la URL completa usando un helper (getCurrentUrl).
  ///   2. Busca el separador (# o %23).
  ///   3. Extrae los parametros del fragmento.
  ///   4. Verifica que el tipo sea "recovery".
  ///   5. Guarda el access_token y refresh_token en almacenamiento seguro.
  ///   6. Devuelve el access_token para que la app pueda usarlo inmediatamente
  ///      para cambiar la contrasena.
  ///
  /// [uri] es la URI que recibio la app al abrir el enlace magico.
  Future<String?> verificarTokenRecuperacion(Uri uri) async {
    // Obtiene la URL completa (maneja diferencias entre plataformas)
    final fullUrl = getCurrentUrl(uri);
    debugPrint('URL raw de recuperacion: $fullUrl');

    // Determina si el separador es # o su forma encodeada %23
    // (depende de como llegue la URL en cada plataforma)
    final separador = fullUrl.contains('%23') ? '%23' : '#';
    final lastIndex = fullUrl.lastIndexOf(separador);
    if (lastIndex == -1) return null;

    // Extrae los parametros del fragmento de la URL (lo que va despues de #)
    final paramString = Uri.decodeComponent(
      fullUrl.substring(lastIndex + separador.length)
    );
    final params = Uri.splitQueryString(paramString);
    debugPrint('Parametros extraidos: $params');

    // Extrae type, access_token y refresh_token
    final type = params['type'];
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];

    // Verifica que exista access_token y que el tipo sea recovery
    if (accessToken == null || type != 'recovery') return null;

    // Guarda los tokens en almacenamiento seguro para usarlos despues
    await guardarToken(accessToken);
    if (refreshToken != null) await guardarRefreshToken(refreshToken);

    debugPrint('Token de recuperacion valido: ${accessToken.substring(0, 20)}...');
    return accessToken;
  }

  /// Muestra errores de red en consola para depuracion.
  /// Si el error tiene respuesta del servidor, muestra el codigo HTTP y los datos.
  /// Si no hay respuesta, muestra el mensaje de error de conexion.
  void _handleError(DioException e) {
    if (e.response != null) {
      debugPrint('Error HTTP ${e.response?.statusCode}: ${e.response?.data}');
    } else {
      debugPrint('Error de conexion: ${e.message}');
    }
  }
}
